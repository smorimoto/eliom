open Parsetree
open Asttypes
open Ast_helper

module AC = Ast_convenience
module AM = Ast_mapper

open Ppx_eliom

let lid_of_str { txt ; loc } =
  { loc ; txt = Longident.Lident txt }


module Pass = struct

  (** {2 Auxiliaries} *)

  (* Replace every escaped identifier [v] with [Eliom_client.Syntax_helpers.get_escaped_value v] *)
  let map_get_escaped_values =
    let mapper =
      {Ast_mapper.default_mapper with
       expr = (fun mapper e ->
         match e.pexp_desc with
         | Pexp_ident {txt} when Mli.is_escaped_ident @@ Longident.last txt ->
           [%expr Eliom_client.Syntax_helpers.get_escaped_value [%e e] ]
         | _ -> e
       );
      }
    in
    fun expr -> mapper.expr mapper expr

  let push_escaped_binding, flush_escaped_bindings =
    let server_arg_ids = ref [] in
    let is_unknown gen_id =
      List.for_all
        (fun (gen_id', _) -> gen_id <> gen_id')
        !server_arg_ids
    in
    let push (gen_id : string Location.loc) (expr : expression) =
      if is_unknown gen_id then
        server_arg_ids := (gen_id, expr) :: !server_arg_ids
    in
    let flush () =
      let res = List.rev !server_arg_ids in
      server_arg_ids := [];
      res
    in
    push, flush

  let push_client_value_data, flush_client_value_datas =
    let client_value_datas = ref [] in
    let push gen_num gen_id expr (args : string Location.loc list) =
      client_value_datas :=
        (gen_num, gen_id, expr, args) :: !client_value_datas
    in
    let flush () =
      let res = List.rev !client_value_datas in
      client_value_datas := [];
      res
    in
    push, flush

  let register_client_closures client_value_datas =
    let registrations =
      List.map
        (fun (num, id, expr, args) ->
           let typ = Mli.find_fragment id in
           let args = List.map Pat.var args in
           [%expr
             Eliom_client.Syntax_helpers.register_client_closure
               [%e Exp.constant @@ Const_int64 num]
               (fun [%p Pat.tuple args] ->
                  ([%e map_get_escaped_values expr] : [%t typ]))
           ] [@metaloc expr.pexp_loc]
        )
        client_value_datas
    in
    [%str
      let () =
        [%e AC.sequence registrations] ;
        ()
    ]

  let define_client_functions ~loc client_value_datas =
    let bindings =
      List.map
        (fun (num, id, expr, args) ->
           let patt = Pat.var id in
           let typ = Mli.find_fragment id in
           let args = List.map Pat.var args in
           let expr =
             [%expr
               fun [%p Pat.tuple args] -> ([%e expr] : [%t typ])
             ] [@metaloc loc]
           in
           Vb.mk ~loc patt expr)
        client_value_datas
    in
    Str.value ~loc Nonrecursive bindings

  (* For injections *)

  let close_server_section loc =
    [%stri
      let () =
        Eliom_client.Syntax_helpers.close_server_section
          [%e AC.str @@ id_of_string !Location.input_name]
    ][@metaloc loc]

  let open_client_section loc =
    [%stri
      let () =
        Eliom_client.Syntax_helpers.open_client_section
          [%e AC.str @@ id_of_string !Location.input_name]
    ][@metaloc loc]

  (** Syntax extension *)

  let client_str item =
    let loc = item.pstr_loc in
    [ open_client_section loc ;
      item ;
    ]

  let server_str item =
    let loc = item.pstr_loc in
    register_client_closures (flush_client_value_datas ()) @
    [ close_server_section loc ]

  let shared_str item =
    let loc = item.pstr_loc in
    let client_expr_data = flush_client_value_datas () in
    open_client_section loc ::
    register_client_closures client_expr_data @
    [ define_client_functions loc client_expr_data ;
      item ;
      close_server_section loc ;
    ]



  let fragment ?typ ~context ~num ~id expr =

    let eid = Exp.ident ~loc:id.loc (lid_of_str id) in
    let escaped_bindings = flush_escaped_bindings () in

    push_client_value_data num id expr
      (List.map fst escaped_bindings);

    match context with
    | `Server ->
      (* We are in a server fragment, this code should always be discarded. *)
      Exp.extension @@ AM.extension_of_error @@ Location.errorf "Eliom: ICE"
    | `Shared ->
      let bindings =
        List.map
          (fun (gen_id, expr) -> Vb.mk (Pat.var gen_id) expr )
          escaped_bindings
      in
      let args =
        Exp.tuple @@ List.map
          (fun (id, _) -> Exp.ident (lid_of_str id))
          escaped_bindings
      in
      let new_e =
        Exp.let_
          Nonrecursive
          bindings
          (Exp.apply eid [ "" , args ])
      in new_e


  let escape_inject ?ident ~(context:Context.escape_inject) ~id orig_expr =
    let loc = orig_expr.pexp_loc in

    let eid = Exp.ident ~loc:id.loc (lid_of_str id) in

    let assert_no_variables t =
      let typ mapper = function
        | {ptyp_desc = Ptyp_var _ ; ptyp_loc } as typ ->
          let attr =
            AM.attribute_of_warning ptyp_loc
              "The type of this injected value contains a type variable \
               that could be wrongly infered."
          in
          { typ with ptyp_attributes = attr :: typ.ptyp_attributes }
        | typ -> mapper.AM.typ mapper typ
      in
      let m = { AM.default_mapper with typ } in
      m.AM.typ m t
    in

    match context with

    (* [%%server [%client ~%( ... ) ] ] *)
    | `Escaped_value section ->
      let typ = Mli.find_escaped_ident id in
      let typ = assert_no_variables typ in
      push_escaped_binding id orig_expr;
      [%expr ([%e eid] : [%t typ]) ]


    (* [%%server ... %x ... ] *)
    | `Injection _section ->
      let typ = Mli.find_injected_ident id in
      let typ = assert_no_variables typ in
      let ident = match ident with
        | None   -> [%expr None]
        | Some i -> [%expr Some [%e AC.evar i]]
      in
      let str_pos =
        AC.str @@
        Format.asprintf "%a" Location.print loc
      in

      [%expr
        (Eliom_client.Syntax_helpers.get_injection
           ?ident:([%e ident])
           ~pos:([%e str_pos])
           [%e Exp.constant ~loc:id.loc (Const_string (id.txt, None))]
         : [%t typ])
      ]

  let shared_sig item = [item]
  let server_sig _    = []
  let client_sig item = [item]

  let prelude _ = []
  let postlude _ = []

end
