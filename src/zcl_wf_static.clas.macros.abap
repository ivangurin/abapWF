*"* use this source file for any macro definitions you need
*"* in the implementation part of the class

define swf_get_element.
  if &1 is bound.
    try.
        call method &1->element_get
          exporting
            name  = &2
          importing
            value = &3.
      catch cx_swf_ifs_exception.
        sy-subrc = 1.
    endtry.
  endif.
end-of-definition.

define swf_set_element.
  if &1 is bound.
    try.
        call method &1->element_set
          exporting
            name  = &2
            value = &3.
      catch cx_swf_ifs_exception.
        sy-subrc = 1.
    endtry.
  endif.
end-of-definition.
