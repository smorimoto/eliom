(* Ocsigen
 * http://www.ocsigen.org
 * Module eliommod.mli
 * Copyright (C) 2005 Vincent Balat
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, with linking exception; 
 * either version 2.1 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
 *)

(** Low level functions for Eliom, exceptions and types. *)

open Extensions


exception Eliom_404 (** Page not found *)
exception Eliom_Wrong_parameter (** Service called with wrong parameter names *)
exception Eliom_Link_too_old (** The coservice does not exist any more *)
exception Eliom_Session_expired
exception Eliom_Service_session_expired of (string list)
    (** The service session cookies does not exist any more.
        The string lists are the list of names of expired sessions
     *)
exception Eliom_Typing_Error of (string * exn) list
    (** The service (GET or POST) parameters do not match expected type *)


exception Eliom_function_forbidden_outside_site_loading of string
    (** That function cannot be used like that outside the
       initialisation phase. 
       For some functions, you must add the [~sp] parameter during a session. 
     *)

(**/**)
(** Type used to describe session timeouts *)
type timeout = 
  | TGlobal (** see global setting *)
  | TNone   (** explicitely set no timeout *)
  | TSome of float (** timeout duration in seconds *)
(* redefined in eliomsessions.ml *)



(** Type used for cookies to set. 
    The float option is the timestamp for the expiration date.
    The strings are names and values.
 *)
type cookie = 
  | Set of url_path option * float option * string * string
  | Unset of url_path option * string
(* redefined in eliomsessions.ml *)


(** The type to send if you want to create your own modules for generating
   pages
 *)
type result_to_send = 
  | EliomResult of Http_frame.result
  | EliomExn of (exn list * cookie list)
(* redefined in eliomservices.ml *)


type cookie_exp =
  | CENothing   (** nothing to set *)
  | CEBrowser   (** expires at browser close *)
  | CESome of float (** expiration date *)

type internal_state = string

type sess_info =
    {si_other_get_params: (string * string) list;
     si_all_get_params: (string * string) list;
     si_all_post_params: (string * string) list;

     si_service_session_cookies: string Http_frame.Cookievalues.t;
     (* the session service cookies sent by the request *)
     (* the key is the cookie name (or site dir) *)

     si_data_session_cookies: string Http_frame.Cookievalues.t;
     (* the session data cookies sent by the request *)
     (* the key is the cookie name (or site dir) *)

     si_persistent_session_cookies: string Http_frame.Cookievalues.t;
     (* the persistent session cookies sent by the request *)
     (* the key is the cookie name (or site dir) *)

     si_nonatt_info: (string option * string option);
     si_state_info: (internal_state option * internal_state option);
     si_config_file_charset: string;
     si_previous_extension_error: int;
     (* HTTP error code sent by previous extension (default: 404) *)
   }


module SessionCookies : Hashtbl.S with type key = string

type tables


type 'a servicecookiestablecontent =
    (string                  (* session fullsessname *) *
     'a                      (* session table *) * 
     float option ref        (* expiration date by timeout 
                                (server side) *) *
     timeout ref             (* user timeout *) *
     Eliomsessiongroups.sessgrp option ref   (* session group *))


type 'a servicecookiestable = 'a servicecookiestablecontent SessionCookies.t

type datacookiestablecontent = 
    (string                  (* session fullsessname *) *
     float option ref        (* expiration date by timeout 
                                (server side) *) *
     timeout ref             (* user timeout *) *
     Eliomsessiongroups.sessgrp option ref   (* session group *))


type datacookiestable = datacookiestablecontent SessionCookies.t

type 'a session_cookie


type 'a one_service_cookie_info =
    (* service sessions: *)
    {sc_value:string             (* current value *);
     sc_table:'a ref             (* service session table
                                    ref towards cookie table
                                  *);
     sc_timeout:timeout ref      (* user timeout - 
                                    ref towards cookie table
                                  *);
     sc_exp:float option ref     (* expiration date ref
                                    (server side) - 
                                    None = never
                                    ref towards cookie table
                                  *);
     sc_cookie_exp:cookie_exp ref (* cookie expiration date to set *);
     sc_session_group:Eliomsessiongroups.sessgrp option ref (* session group *)
   }


type one_data_cookie_info =
    (* in memory data sessions: *)
    {dc_value:string                    (* current value *);
     dc_timeout:timeout ref             (* user timeout - 
                                           ref towards cookie table
                                         *);
     dc_exp:float option ref            (* expiration date ref (server side) - 
                                           None = never
                                           ref towards cookie table
                                         *);
     dc_cookie_exp:cookie_exp ref       (* cookie expiration date to set *);
     dc_session_group:Eliomsessiongroups.sessgrp option ref (* session group *)
   }

type one_persistent_cookie_info =
     {pc_value:string                    (* current value *);
      pc_timeout:timeout ref             (* user timeout *); 
      pc_cookie_exp:cookie_exp ref       (* cookie expiration date to set *);
      pc_session_group:Eliomsessiongroups.perssessgrp option ref (* session group *)
    }




type 'a cookie_info =
    (* service sessions: *)
    (string option            (* value sent by the browser *)
                              (* None = new cookie 
                                 (not sent by the browser) *)
       *
       
       'a one_service_cookie_info session_cookie ref
       (* SCNo_data = the session has been closed
          SCData_session_expired = the cookie has not been found in the table.
          For both of them, ask the browser to remove the cookie.
        *)
    )
      (* This one is not lazy because we must check all service sessions
         at each request to find the services *)
      Http_frame.Cookievalues.t ref (* The key is the full session name *) *
      
    (* in memory data sessions: *)
      (string option            (* value sent by the browser *)
                                (* None = new cookie 
                                   (not sent by the browser) *)
         *
         
         one_data_cookie_info session_cookie ref
         (* SCNo_data = the session has been closed
            SCData_session_expired = the cookie has not been found in the table.
            For both of them, ask the browser to remove the cookie.
          *)
      ) Lazy.t
      (* Lazy because we do not want to ask the browser to unset the cookie 
         if the cookie has not been used, otherwise it is impossible to 
         write a message "Your session has expired" *)
      Http_frame.Cookievalues.t ref (* The key is the full session name *) *
      
      (* persistent sessions: *)
      ((string                  (* value sent by the browser *) *
        timeout                 (* timeout at the beginning of the request *) *
        float option            (* (server side) expdate 
                                   at the beginning of the request
                                   None = no exp *) *
        Eliomsessiongroups.perssessgrp option      (* session group at beginning of request *))
         option
                                (* None = new cookie 
                                   (not sent by the browser) *)
         *
         
         one_persistent_cookie_info session_cookie ref
         (* SCNo_data = the session has been closed
            SCData_session_expired = the cookie has not been found in the table.
            For both of them, ask the browser to remove the cookie.
          *)
      ) Lwt.t Lazy.t
      Http_frame.Cookievalues.t ref


(** Common data for the whole site *)
type sitedata =
   {site_dir: url_path;
   site_dir_string: string;
   mutable servtimeout: (string * float option) list;
   mutable datatimeout: (string * float option) list;
   mutable perstimeout: (string * float option) list;
   global_services: tables; (* global service table *)
   session_services: tables servicecookiestable; (* cookie table for services *)
   session_data: datacookiestable; (* cookie table for in memory session data *)
   mutable remove_session_data: string -> unit;
   mutable not_bound_in_data_tables: string -> bool;
   mutable exn_handler: server_params -> exn -> result_to_send Lwt.t;
   mutable unregistered_services: url_path option list;
   mutable max_volatile_data_sessions_per_group: int option;
   mutable max_service_sessions_per_group: int option;
   mutable max_persistent_data_sessions_per_group: int option;
 }


(** Type of server parameters. 
    This is the type of the first parameter of service handlers (sp).
 *)
and server_params = 
    {sp_ri:request_info;
     sp_si:sess_info;
     sp_sitedata:sitedata (* data for the whole site *);
     sp_cookie_info:tables cookie_info;
     sp_suffix:url_path (* suffix *);
     sp_fullsessname:string option (* the name of the session
                                      to which belong the service
                                      that answered
                                      (if it is a session service) *)}


exception Eliom_duplicate_registration of string (** The service has been registered twice*)
exception Eliom_page_erasing of string (** The location where you want to register something already exists *)
exception Eliom_there_are_unregistered_services of (string list * 
                                                      string list option list)
(** Some services have not been registered. The first string list is the path
 of the site, the string list option list is the list of unregistered services.
    [None] means non-attached.
 *)
exception Eliom_error_while_loading_site of string


type anon_params_type = int






      

val persistent_cookies_table :
  (string * float option * timeout * Eliomsessiongroups.perssessgrp option)
    Ocsipersist.table


type page_table_key =
    {key_state: (internal_state option * internal_state option);
     key_kind: Http_frame.Http_header.http_method}


val empty_tables : unit -> tables

val add_service :
    tables ->
      bool ->
        string list ->
          page_table_key *
            ((anon_params_type * anon_params_type) * 
               int ref option *
               (float * float ref) option *
               (server_params -> result_to_send Lwt.t)) ->
                 unit

val add_naservice :
    tables -> 
      bool -> 
	(string option * string option) -> 
          (int ref option *
             (float * float ref) option *
	     (server_params -> result_to_send Lwt.t))
          -> unit


val get_state_param_name : string
val post_state_param_name : string
val eliom_suffix_name : string
val eliom_suffix_internal_name : string
val naservice_name : string
val co_param_prefix : string
val na_co_param_prefix : string

val config : Simplexmlparser.xml list ref


val set_global_service_timeout :
    session_name:string option ->
    recompute_expdates:bool ->
    sitedata ->
    float option -> unit Lwt.t

val get_global_service_timeout : 
    session_name:string option -> sitedata -> float option

val set_global_data_timeout :
    session_name:string option ->
    recompute_expdates:bool ->
    sitedata ->
    float option -> unit Lwt.t

val get_global_data_timeout : 
    session_name:string option -> sitedata -> float option

val set_global_persistent_timeout :
    session_name:string option ->
    recompute_expdates:bool ->
    sitedata -> float option -> unit Lwt.t

val get_global_persistent_timeout : session_name:string option ->
  sitedata -> float option

val get_default_service_timeout : unit -> float option

val set_default_service_timeout : float option -> unit

val get_default_data_timeout : unit -> float option

val set_default_data_timeout : float option -> unit

val set_default_volatile_timeout : float option -> unit

val get_default_persistent_timeout : unit -> float option

val set_default_persistent_timeout : float option -> unit


val create_volatile_table : unit -> 'a SessionCookies.t
val create_volatile_table_during_session : server_params -> 'a SessionCookies.t
val create_persistent_table : string -> 'a Ocsipersist.table
val remove_from_all_persistent_tables : string -> unit Lwt.t

val find_or_create_service_cookie : 
    ?session_group:string -> 
      ?session_name:string -> 
        sp:server_params -> 
          unit -> 
            tables one_service_cookie_info

val find_service_cookie_only : 
    ?session_name:string -> sp:server_params -> unit -> 
      tables one_service_cookie_info

val find_or_create_data_cookie : 
    ?session_group:string -> 
      ?session_name:string -> 
        sp:server_params -> unit -> one_data_cookie_info

val find_data_cookie_only : 
    ?session_name:string -> sp:server_params -> unit -> one_data_cookie_info

val find_or_create_persistent_cookie : 
    ?session_group:string -> 
      ?session_name:string -> 
        sp:server_params -> 
          unit ->
            one_persistent_cookie_info Lwt.t
            
val find_persistent_cookie_only : 
    ?session_name:string -> sp:server_params -> unit -> 
      one_persistent_cookie_info Lwt.t



val close_service_session2 :
    sitedata -> Eliomsessiongroups.sessgrp option -> string -> unit

val close_service_session :
  ?close_group:bool ->
    ?session_name:string -> sp:server_params -> unit -> unit

val close_service_group : sitedata -> Eliomsessiongroups.sessgrp option -> unit

val close_data_session2 : sitedata -> Eliomsessiongroups.sessgrp option -> string -> unit

val close_data_session :
  ?close_group:bool ->
  ?session_name:string -> 
  sp:server_params -> 
  unit -> 
  unit

val close_data_group : sitedata -> Eliomsessiongroups.sessgrp option -> unit

val close_volatile_session :
  ?close_group:bool ->
  ?session_name:string -> 
  sp:server_params -> 
  unit -> 
  unit

val close_persistent_session2 : 
  Eliomsessiongroups.perssessgrp option -> 
  string ->
  unit Lwt.t

val close_persistent_session :
  ?close_group:bool ->
  ?session_name:string -> 
  sp:server_params -> 
  unit -> 
  unit Lwt.t

val close_persistent_group : Eliomsessiongroups.perssessgrp option -> unit Lwt.t

val close_all_service_sessions :
  ?close_group:bool ->
  ?session_name:string -> 
  sitedata -> 
  unit Lwt.t

val close_all_data_sessions :
  ?close_group:bool ->
  ?session_name:string -> 
  sitedata -> 
  unit Lwt.t

val close_all_persistent_sessions :
  ?close_group:bool ->
  ?session_name:string -> 
  sitedata -> 
  unit Lwt.t


val iter_service_sessions :
    sitedata -> 
      (SessionCookies.key * tables servicecookiestablecontent * sitedata -> unit Lwt.t)
      -> unit Lwt.t

val iter_data_sessions :
    sitedata -> 
      (SessionCookies.key * datacookiestablecontent * sitedata -> unit Lwt.t) -> unit Lwt.t

val iter_persistent_sessions :
  (string * (string * float option * timeout * 
               Eliomsessiongroups.perssessgrp option) -> 
     unit Lwt.t) -> 
  unit Lwt.t

val fold_service_sessions :
  sitedata -> 
  (SessionCookies.key * tables servicecookiestablecontent * 
     sitedata -> 'c -> 'c Lwt.t)
  -> 'c -> 'c Lwt.t

val fold_data_sessions :
    sitedata -> 
      (SessionCookies.key * datacookiestablecontent * sitedata -> 'c -> 'c Lwt.t) -> 
        'c -> 'c Lwt.t

val fold_persistent_sessions :
  (string * (string * float option * timeout * 
               Eliomsessiongroups.perssessgrp option) -> 
     'c -> 'c Lwt.t) -> 'c -> 'c Lwt.t



(** Profiling *)
val number_of_service_sessions : sp:server_params -> int
val number_of_data_sessions : sp:server_params -> int
val number_of_tables : unit -> int
val number_of_table_elements : unit -> int list
val number_of_persistent_sessions : unit -> int Lwt.t
val number_of_persistent_tables : unit -> int
(** Number of persistent tables opened *)
val number_of_persistent_table_elements : unit -> (string * int) list Lwt.t
(** Whole number of elements in all persistent tables, table by table *)



(** internal functions: *)
val add_unregistered : sitedata -> string list option -> unit
val remove_unregistered : sitedata -> string list option -> unit
val global_register_allowed : unit -> (unit -> sitedata) option


val add_cookie_list_to_send :
    sitedata -> cookie list -> Http_frame.cookieset -> Http_frame.cookieset

