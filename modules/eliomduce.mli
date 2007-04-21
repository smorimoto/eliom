open Xhtml1_strict

module Xhtml : Eliom.ELIOMSIG with 
type page = html
and type form_content_elt = form_content
and type form_content_elt_list = {{ [ form_content* ] }}
and type uri = string
and type a_content_elt = a_content
and type a_content_elt_list = {{ [ a_content* ] }}
and type div_content_elt = flows
and type div_content_elt_list = {{ [ flows* ] }}
and type a_elt = a
and type a_elt_list = {{ [ a* ] }}
and type form_elt = form
and type textarea_elt = textarea
and type select_elt = select
and type input_elt = input
and type link_elt = link
and type script_elt = script
and type pcdata_elt = {{ [ PCDATA ] }}
and type a_attrib_t = a_attrs
and type form_attrib_t = 
    {{ attrs ++ { accept-charset=?String accept=?String 
	          onreset=?String onsubmit=?String enctype=?String } }}
and type input_attrib_t = input_attrs
and type textarea_attrib_t = {{ attrs ++ focus ++ 
	{ onchange=?String
            onselect=?String 
	    readonly=?"readonly" 
            disabled=?"disabled" 
	    name=?String } }}
and type select_attrib_t = select_attrs
and type link_attrib_t = link_attrs
and type script_attrib_t = 
    {{ id ++ { defer=?"defer" src=?String charset=?String } }}
and type input_type_t = input_type_values
