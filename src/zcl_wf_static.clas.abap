class zcl_wf_static definition
  public
  final
  create public .

*"* public components of class ZCL_WF_STATIC
*"* do not include other source files here!!!
  public section.

    class-methods lock
      importing
        !i_wi_id type sww_wiid
      raising
        zcx_generic .
    class-methods unlock
      importing
        !i_wi_id type sww_wiid .
    class-methods get_value
      importing
        !i_wi_id type sww_wiid
        !i_name  type swfdname
      exporting
        !e_value type any
      raising
        zcx_generic .
    class-methods set_value
      importing
        !i_wi_id  type sww_wiid
        !i_name   type swfdname
        !i_value  type any
        !i_commit type abap_bool default abap_false
      raising
        zcx_generic .
    class-methods get_container
      importing
        !i_wi_id type sww_wiid
      exporting
        !et_cont type swrtcont
      raising
        zcx_generic .
    class-methods set_container
      importing
        !i_wi_id  type sww_wiid
        !it_cont  type swrtcont
        !i_commit type abap_bool default abap_false
      raising
        zcx_generic .
    class-methods get_context
      importing
        !i_id             type sww_wiid
      returning
        value(er_context) type ref to if_wapi_workitem_context
      raising
        zcx_generic .
    class-methods complete
      importing
        !i_wi_id  type sww_wiid
        !it_cont  type swrtcont optional
        !i_commit type abap_bool default abap_false
      raising
        zcx_generic .
    class-methods complete_manual
      importing
        !i_id type simple
      raising
        zcx_generic .
    class-methods get_wi_by_users
      importing
        !it_users    type zirange
        !i_task_id   type simple
      returning
        value(et_wi) type stringtab .
    class-methods get_substitutes
      importing
        !i_user         type simple default sy-uname
        !i_substitutes  type abap_bool default abap_true
      changing
        !ct_substitutes type stringtab .
    class-methods forward
      importing
        !i_id type simple
        !i_to type simple default sy-uname
        !i_by type simple default sy-uname
      raising
        zcx_generic .
  protected section.
*"* protected components of class ZCL_WF_STATIC
*"* do not include other source files here!!!
private section.
ENDCLASS.



CLASS ZCL_WF_STATIC IMPLEMENTATION.


  method complete.

    data:
      l_rc        like          sy-subrc,
      lt_messages type table of swr_mstruc,
      ls_message  like line of  lt_messages.

    call function 'SAP_WAPI_WORKITEM_COMPLETE'
      exporting
        workitem_id      = i_wi_id
        do_commit        = i_commit
      importing
        return_code      = l_rc
      tables
        simple_container = it_cont
        message_struct   = lt_messages.

    loop at lt_messages transporting no fields
      where
        msgty ca 'EAX'.
      zcx_generic=>raise(
        it_messages = lt_messages ).
    endloop.

  endmethod.


  method complete_manual.

    constants:
      notes_contelem_name   type swc_elem value swfco_notes_contelem_name,
      attach_contelem_name  type swc_elem value swfco_attach_contelem_name,
      adhoc_contelem_name   type swc_elem value swfco_adhoc_contelem_name,
      wi_comp_event_name    type swc_elem value swfco_wi_comp_event_name,
      wi_comp_event_objtype type swc_elem value swfco_wi_comp_event_objtype,
      wi_comp_event_objkey  type swc_elem value swfco_wi_comp_event_objkey,
      wi_comp_event_catid   type swc_elem value swfco_wi_comp_event_catid.

    data l_id type swwwihead-wi_id.
    l_id = i_id.

    data ls_flow_info type swp_wi_req.
    call function 'SWP_WI_CREATOR_GET'
      exporting
        wi_id              = l_id
      importing
        wi_req_workflow    = ls_flow_info
      exceptions
        no_parent_workflow = 1.
    if sy-subrc ne 0.
      zcx_generic=>raise( ).
    endif.

    data ls_wf_def_key type swd_wfdkey.
    call function 'SWP_WF_DEFINITION_KEY_GET'
      exporting
        wf_id              = ls_flow_info-wf_id
      importing
        wf_def_key         = ls_wf_def_key
      exceptions
        workflow_not_found = 1.
    if sy-subrc ne 0.
      zcx_generic=>raise( ).
    endif.

    data ls_flowitem type swlc_workitem.
    call function 'SWL_WI_HEADER_READ'
      exporting
        wi_id              = ls_flow_info-wf_id
      changing
        workitem           = ls_flowitem
      exceptions
        workitem_not_found = 1.
    if sy-subrc ne 0.
      zcx_generic=>raise( ).
    endif.

    data l_task type swd_ahead-task.
    l_task = ls_flowitem-wi_rh_task.

    data l_tab_results type swd_data-xfeld.
    data lt_successor_events type table of swd_succes.
    call function 'SWD_GET_SUCCESSOR_EVENTS'
      exporting
        act_wfdkey         = ls_wf_def_key
        act_task           = l_task
        act_nodeid         = ls_flow_info-node_id
      importing
        tab_result         = l_tab_results
      tables
        successor_events   = lt_successor_events
      exceptions
        workflow_not_found = 1
        node_not_found     = 2.
    if sy-subrc ne 0.
      zcx_generic=>raise( ).
    endif.

    data lt_modeled_event_data type table of swl_succes.
    zcl_abap_static=>table2table(
      exporting it_data = lt_successor_events
      importing et_data = lt_modeled_event_data ).

    data ls_modeled_event_data like line of lt_modeled_event_data.
    read table lt_modeled_event_data into ls_modeled_event_data
      with key
        evt_type = 'EXECUTED'.

    check sy-subrc eq 0.

    try.

        data lr_txmgr type ref to cl_swf_run_transaction_manager.
        lr_txmgr =
          cl_swf_run_transaction_manager=>get_instance(
            im_enqueue_owner = 'SWW_WI_MANUALLY_COMPLETE' ).

        data lr_wi_handle type ref to if_swf_run_wim_internal.
        lr_wi_handle =
          cl_swf_run_wim_factory=>find_by_wiid(
            im_wiid            = l_id
            im_read_for_update = 'X'
            im_tx              = lr_txmgr ).

        data lr_container type ref to if_swf_cnt_container.
        lr_container = lr_wi_handle->get_wi_container( ).

        data lr_result type ref to cl_swf_run_result.
        lr_result =
          cl_swf_run_result=>get_instance(
            im_wi_handle = lr_wi_handle ).

        if ls_modeled_event_data-evt_result eq abap_true or
           ( ls_modeled_event_data-evt_except eq abap_true and ls_modeled_event_data-return eq '0000' ).

          data l_result_string type string.
          l_result_string = ls_modeled_event_data-returncode.

          data ls_swf_return type swf_return.
          lr_result->set_main_method_result(
              im_return           = ls_swf_return
              im_result_string    = l_result_string ).

          swf_set_element lr_container
                          swfco_wi_result_const
                          l_result_string.


        elseif ls_modeled_event_data-evt_detevt eq abap_true.

          data name type swfdname.
          name = ls_modeled_event_data-evt_contel.

          data ls_ibfobject type sibflporb.
          swf_get_element lr_container
                      name
                      ls_ibfobject.

          data l_event_name type sibfevent.
          l_event_name = ls_modeled_event_data-evt_type.

          data lr_event type ref to if_swf_run_wim_event.
          lr_event =
            cl_swf_run_event=>get_instance(
              im_event = l_event_name
              im_sender = ls_ibfobject ).

          lr_result->set_event( im_event = lr_event ).


          swf_set_element lr_container
                          wi_comp_event_name
                          ls_modeled_event_data-evt_type.

          if ls_modeled_event_data-evt_catid is initial.
            ls_modeled_event_data-evt_catid = swfco_objtype_bor.
          endif.
          swf_set_element lr_container
                          wi_comp_event_catid
                          ls_modeled_event_data-evt_catid.
          swf_set_element lr_container
                          wi_comp_event_objtype
                          ls_modeled_event_data-evt_otype.
          swf_set_element lr_container
                          wi_comp_event_objkey
                          ls_ibfobject-instid.
        elseif ls_modeled_event_data-evt_desevt eq abap_true.
          l_result_string = ls_modeled_event_data-returncode.
          lr_result->set_main_method_result(
              im_return           = ls_swf_return
              im_result_string    = l_result_string
                 ).
          swf_set_element lr_container
                          swfco_wi_result_const
                          l_result_string.
        elseif ls_modeled_event_data-evt_except eq abap_true.

          data ls_exception_data type sww_excdat.
          ls_exception_data-return-code = ls_modeled_event_data-return.

          if ls_modeled_event_data-error_1 eq 'X'.
            ls_exception_data-return-errortype = 1.
          elseif ls_modeled_event_data-error_2 eq 'X'.
            ls_exception_data-return-errortype = 2.
          endif.

          ls_exception_data-return-workarea = ls_modeled_event_data-arbgb.
          ls_exception_data-return-message  = ls_modeled_event_data-msgnr.
          ls_exception_data-return-msgtyp = 'W'.
          lr_result->set_exception( im_exception_data = ls_exception_data   ).

        endif.

        data ls_result_for_container type swf_wiresult.
        ls_result_for_container = lr_result->get_result( ).

        data ls_result_manually type swf_wiresult_manually_complete.
        move-corresponding ls_result_for_container to ls_result_manually.

        if lr_wi_handle->m_sww_wihead-wi_type eq swfco_wi_batch.
          while lr_wi_handle->m_sww_wihead-retry_cnt lt 99.
            lr_wi_handle->increment_retry_counter( ).
          endwhile.
        endif.

        if ls_result_for_container-type eq ls_result_manually-type and
           ls_result_for_container-value eq ls_result_manually-value.
          lr_container->element_set(
            exporting
              name             = swfco_manually_result_const
              value            = ls_result_manually ).
          call method lr_txmgr->save( ).
          call method lr_txmgr->commit( ).
        else.
        endif.

        call method lr_txmgr->dequeue( ).

        data lr_excp type ref to cx_swf_ifs_exception.
      catch cx_swf_ifs_exception into lr_excp.
    endtry.

    check lr_wi_handle->m_sww_wihead-wi_stat ne 'ERROR'.

    call function 'SWW_WI_ADMIN_COMPLETE'
      exporting
        wi_id                       = l_id
        do_commit                   = abap_true
        authorization_checked       = abap_false
      exceptions
        update_failed               = 01
        infeasible_state_transition = 03
        no_authorization            = 02.
    if sy-subrc ne 0.
      zcx_generic=>raise( ).
    endif.

  endmethod.


  method forward.

    check i_id is not initial.

    data l_id type swwwihead-wi_id.
    l_id = i_id.

    data l_to type sy-uname.
    l_to = i_to.

    data l_by type sy-uname.
    l_by = i_by.

    call function 'SAP_WAPI_FORWARD_WORKITEM'
      exporting
        workitem_id  = l_id
        user_id      = l_to
        current_user = l_by
        do_commit    = abap_true.

  endmethod.


  method get_container.

    data:
      l_rc        like          sy-subrc,
      lt_messages type table of swr_mstruc,
      ls_message  like line of  lt_messages.

    call function 'SAP_WAPI_READ_CONTAINER'
      exporting
        workitem_id      = i_wi_id
      importing
        return_code      = l_rc
      tables
        simple_container = et_cont
        message_struct   = lt_messages.

    loop at lt_messages transporting no fields
      where msgty ca 'EAX'.
      zcx_generic=>raise( it_messages = lt_messages ).
    endloop.

  endmethod.


  method get_context.

    try.
        er_context ?= cl_swf_run_workitem_context=>get_instance( i_id ).
        data lx_root type ref to cx_root.
      catch cx_root into lx_root.
        zcx_generic=>raise( ix_root = lx_root ).
    endtry.

  endmethod.


  method get_substitutes.

    data ls_substituted_object type swragent.
    ls_substituted_object-otype = 'US'.
    ls_substituted_object-objid = i_user.

    data lt_substitutes type table of swr_substitute.
    call function 'SAP_WAPI_SUBSTITUTES_GET'
      exporting
        substituted_object = ls_substituted_object
      tables
        substitutes        = lt_substitutes.

    data ls_substitute like line of lt_substitutes.
    loop at lt_substitutes into ls_substitute.

      read table ct_substitutes transporting no fields
        with key table_line = ls_substitute-objid.
      check sy-subrc ne 0.

      data l_substitute like line of ct_substitutes.
      l_substitute = ls_substitute-objid.
      insert l_substitute into table ct_substitutes.

      get_substitutes(
        exporting
          i_user         = l_substitute
        changing
          ct_substitutes = ct_substitutes ).

    endloop.

  endmethod.


  method get_value.

    " Get contaner handle
    data lo_cont type ref to if_swf_cnt_container.
    call function 'SWW_WI_CONTAINER_READ'
      exporting
        wi_id                    = i_wi_id
      importing
        wi_container_handle      = lo_cont
      exceptions
        container_does_not_exist = 1
        read_failed              = 2
        others                   = 3.
    if sy-subrc ne 0.
      zcx_generic=>raise( ).
    endif.

    " Get value
    try.
        lo_cont->if_swf_cnt_element_access_1~element_get_value(
          exporting name  = i_name
          importing value = e_value ).
        data lx_root type ref to cx_root.
      catch cx_root into lx_root.
        zcx_generic=>raise( ix_root = lx_root ).
    endtry.

  endmethod.


  method get_wi_by_users.

    select user~wi_id
      from swwuserwi as user
        join swwwihead as ts
          on ts~wi_id eq user~wi_id
      into table et_wi
      where user~user_id  in it_users and
            user~task_obj eq i_task_id.

  endmethod.


  method lock.

    call function 'SWL_WI_ENQUEUE'
      exporting
        wi_id                     = i_wi_id
      exceptions
        wi_locked_by_another_user = 1
        wi_enqueue_failed         = 2
        others                    = 3.
    if sy-subrc <> 0.
      zcx_generic=>raise( ).
    endif.

  endmethod.


  method set_container.

    data:
      l_rc        like          sy-subrc,
      lt_messages type table of swr_mstruc,
      ls_message  like line of  lt_messages.

    call function 'SAP_WAPI_WRITE_CONTAINER'
      exporting
        workitem_id      = i_wi_id
        do_commit        = i_commit
      importing
        return_code      = l_rc
      tables
        simple_container = it_cont
        message_struct   = lt_messages.

    loop at lt_messages transporting no fields
      where msgty ca 'EAX'.
      zcx_generic=>raise( it_messages = lt_messages ).
    endloop.

  endmethod.


  method set_value.

    data:
      lt_cont type         swrtcont,
      ls_cont like line of lt_cont.

    ls_cont-element = i_name.
    ls_cont-value   = i_value.
    insert ls_cont into table lt_cont.

    set_container(
      i_wi_id  = i_wi_id
      it_cont  = lt_cont
      i_commit = i_commit ).

  endmethod.


  method unlock.

    call function 'DEQUEUE_E_WORKITEM'
      exporting
        wi_id = i_wi_id.

  endmethod.
ENDCLASS.
