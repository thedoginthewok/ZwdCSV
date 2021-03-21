CLASS zcl_wd_csv_dyn_helper DEFINITION PUBLIC CREATE PUBLIC.
  PUBLIC SECTION.
    TYPES:
      BEGIN OF mty_s_name_mapping,
        csv  TYPE string,
        abap TYPE string,
      END OF mty_s_name_mapping,
      mty_t_name_mapping TYPE STANDARD TABLE OF mty_s_name_mapping WITH DEFAULT KEY.
    METHODS:
      constructor IMPORTING iv_csv TYPE string,
      generate_struct_type IMPORTING iv_endofline               TYPE csequence                 DEFAULT zcl_wd_csv=>mc_endofline_cr_lf
                                     iv_separator               TYPE zcl_wd_csv=>mty_separator DEFAULT zcl_wd_csv=>mc_separator_tab
                                     iv_delimiter               TYPE zcl_wd_csv=>mty_delimiter DEFAULT zcl_wd_csv=>mc_delimiter_double_quote
                                     iv_use_header_as_comp_name TYPE abap_bool DEFAULT abap_false
                                     it_name_mapping            TYPE mty_t_name_mapping OPTIONAL
                           RETURNING VALUE(ro_struct_descr)     TYPE REF TO cl_abap_structdescr
                           RAISING   zcx_wd_csv_invalid_endofline
                                     zcx_wd_csv_invalid_separator
                                     zcx_wd_csv_invalid_delimiter
                                     RESUMABLE(zcx_wd_csv_mixed_endofline)
                                     cx_sy_struct_creation
                                     cx_sy_table_creation,
      generate_table_type IMPORTING iv_endofline               TYPE csequence                 DEFAULT zcl_wd_csv=>mc_endofline_cr_lf
                                    iv_separator               TYPE zcl_wd_csv=>mty_separator DEFAULT zcl_wd_csv=>mc_separator_tab
                                    iv_delimiter               TYPE zcl_wd_csv=>mty_delimiter DEFAULT zcl_wd_csv=>mc_delimiter_double_quote
                                    iv_use_header_as_comp_name TYPE abap_bool DEFAULT abap_false
                                    it_name_mapping            TYPE mty_t_name_mapping OPTIONAL
                          RETURNING VALUE(ro_table_descr)      TYPE REF TO cl_abap_tabledescr
                          RAISING   zcx_wd_csv_invalid_endofline
                                    zcx_wd_csv_invalid_separator
                                    zcx_wd_csv_invalid_delimiter
                                    RESUMABLE(zcx_wd_csv_mixed_endofline)
                                    cx_sy_struct_creation
                                    cx_sy_table_creation.
  PROTECTED SECTION.
    DATA:
      mv_csv TYPE string.
    METHODS:
      user_header_as_comp_name IMPORTING iv_endofline           TYPE csequence
                                         iv_separator           TYPE zcl_wd_csv=>mty_separator
                                         iv_delimiter           TYPE zcl_wd_csv=>mty_delimiter
                                         io_struct_descr        TYPE REF TO cl_abap_structdescr
                                         it_components          TYPE cl_abap_structdescr=>component_table
                                         iv_first_line          TYPE string
                                         it_name_mapping        TYPE mty_t_name_mapping OPTIONAL
                               RETURNING VALUE(ro_struct_descr) TYPE REF TO cl_abap_structdescr
                               RAISING   zcx_wd_csv_invalid_endofline
                                         zcx_wd_csv_invalid_separator
                                         zcx_wd_csv_invalid_delimiter
                                         zcx_wd_csv_mixed_endofline
                                         cx_sy_table_creation
                                         cx_sy_struct_creation
                                         cx_sy_conversion_error,
      get_column_name IMPORTING iv_col_index       TYPE i
                      RETURNING VALUE(rv_col_name) TYPE string.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_wd_csv_dyn_helper IMPLEMENTATION.


  METHOD constructor.
* ----------------------------------------------------------------------
    mv_csv = iv_csv.

* ----------------------------------------------------------------------
  ENDMETHOD.


  METHOD generate_struct_type.
* ----------------------------------------------------------------------
    " reuse input validation of zcl_wd_csv
    NEW zcl_wd_csv( iv_endofline   = iv_endofline
                    iv_separator   = iv_separator
                    iv_delimiter   = iv_delimiter
                    iv_conv_exit   = abap_false
                    iv_trim_spaces = abap_false ).

* ----------------------------------------------------------------------
    DATA:
      lv_str_length TYPE i,
      lv_str_pos    TYPE i,
      lv_str_pos_p1 TYPE i,
      lv_curr_line  TYPE i,
      lv_component  TYPE i,
      lv_delimited  TYPE abap_bool,
      lv_in_cell    TYPE abap_bool,
      lv_first_line TYPE string,
      lt_components TYPE cl_abap_structdescr=>component_table.

* ---------------------------------------------------------------------
    DEFINE continue_loop.
**********************************************************************
      lv_str_pos = lv_str_pos + 1.
      CONTINUE.
**********************************************************************
    END-OF-DEFINITION.

* ---------------------------------------------------------------------
    DO.
      CASE mv_csv+lv_str_pos(1).
        WHEN iv_delimiter.
          CASE lv_delimited.
            WHEN abap_false.
              lv_delimited = abap_true.
            WHEN abap_true.
              IF ( lv_str_length - lv_str_pos ) >= 2 " make sure at least two characters are left in the string
              AND mv_csv+lv_str_pos(2) = iv_delimiter && iv_delimiter.
                " if the current csv cell is delimited and double double quotes are in it, add one of them to the abap cell
*                append_character.
                lv_str_pos = lv_str_pos + 1.
                continue_loop.
              ELSE.
                lv_delimited = abap_false.
              ENDIF.
          ENDCASE.
        WHEN iv_separator.
          IF lv_delimited = abap_true.
            continue_loop.
          ENDIF.
          lv_in_cell = abap_false.
          lv_component = lv_component + 1.
        WHEN zcl_wd_csv=>mc_endofline_lf OR zcl_wd_csv=>mc_endofline_cr_lf(1).
          IF lv_delimited = abap_true.
            continue_loop.
          ENDIF.
          IF (     iv_endofline = zcl_wd_csv=>mc_endofline_cr_lf
               AND mv_csv+lv_str_pos(2) <> zcl_wd_csv=>mc_endofline_cr_lf )
          OR (     iv_endofline = zcl_wd_csv=>mc_endofline_lf
               AND mv_csv+lv_str_pos(1) <> zcl_wd_csv=>mc_endofline_lf    )
          OR (     iv_endofline = zcl_wd_csv=>mc_endofline_cr
               AND mv_csv+lv_str_pos(1) <> zcl_wd_csv=>mc_endofline_cr    ).
            RAISE RESUMABLE EXCEPTION TYPE zcx_wd_csv_mixed_endofline
              EXPORTING
                line = lv_curr_line.
          ENDIF.
          CASE iv_endofline.
            WHEN zcl_wd_csv=>mc_endofline_cr OR zcl_wd_csv=>mc_endofline_lf.
              lv_str_pos_p1 = lv_str_pos + 1.
            WHEN zcl_wd_csv=>mc_endofline_cr_lf ##WHEN_DOUBLE_OK.
              lv_str_pos_p1 = lv_str_pos + 2.
          ENDCASE.
          IF mv_csv+lv_str_pos_p1 CO space.
            EXIT.
          ENDIF.
          IF iv_endofline = zcl_wd_csv=>mc_endofline_cr_lf.
            " advance position because crlf is two characters
            lv_str_pos = lv_str_pos + 1.
          ENDIF.
          IF iv_use_header_as_comp_name = abap_true
          AND lv_curr_line = 0.
            lv_first_line = mv_csv(lv_str_pos).
          ENDIF.
          lv_curr_line = lv_curr_line + 1.
          IF lv_curr_line = 3.
            " parse max two lines
            EXIT.
          ENDIF.
          lv_component = 1.
        WHEN ` `.
          IF lv_delimited = abap_true
          OR lv_in_cell   = abap_true.
            continue_loop.
          ENDIF.
        WHEN OTHERS.
          lv_in_cell = abap_true.
      ENDCASE.
      IF ( lv_str_pos + 1 ) = lv_str_length.
        EXIT.
      ENDIF.
      lv_str_pos = lv_str_pos + 1.
    ENDDO.

* ----------------------------------------------------------------------
    DO lv_component TIMES.
      APPEND VALUE #( name = get_column_name( sy-index )
                      type = cl_abap_elemdescr=>get_string( )
      ) TO lt_components.
    ENDDO.
    ro_struct_descr = cl_abap_structdescr=>create( lt_components ).

* ----------------------------------------------------------------------
    IF iv_use_header_as_comp_name = abap_false.
      RETURN.
    ENDIF.
    ro_struct_descr = user_header_as_comp_name( iv_endofline    = iv_endofline
                                                iv_delimiter    = iv_delimiter
                                                iv_separator    = iv_separator
                                                io_struct_descr = ro_struct_descr
                                                it_components   = lt_components
                                                iv_first_line   = lv_first_line
                                                it_name_mapping = it_name_mapping ).

* ----------------------------------------------------------------------
  ENDMETHOD.


  METHOD generate_table_type.
* ----------------------------------------------------------------------
    ro_table_descr = cl_abap_tabledescr=>create( p_line_type  = generate_struct_type( iv_endofline               = iv_endofline
                                                                                      iv_separator               = iv_separator
                                                                                      iv_delimiter               = iv_delimiter
                                                                                      iv_use_header_as_comp_name = iv_use_header_as_comp_name
                                                                                      it_name_mapping            = it_name_mapping )
                                                 p_table_kind = cl_abap_tabledescr=>tablekind_std ).

* ----------------------------------------------------------------------
  ENDMETHOD.


  METHOD user_header_as_comp_name.
* ----------------------------------------------------------------------
    DATA:
      ld_table      TYPE REF TO data,
      lt_components LIKE it_components.
    FIELD-SYMBOLS:
      <lt_table> TYPE STANDARD TABLE.

* ----------------------------------------------------------------------
    DATA(lo_table_descr) = cl_abap_tabledescr=>create( io_struct_descr ).
    CREATE DATA ld_table TYPE HANDLE lo_table_descr.
    ASSIGN ld_table->* TO <lt_table>.

* ----------------------------------------------------------------------
    TRY.
        NEW zcl_wd_csv( iv_endofline   = iv_endofline
                        iv_separator   = iv_separator
                        iv_delimiter   = iv_delimiter
                        iv_conv_exit   = abap_false
                        iv_trim_spaces = abap_true    )->parse_string( EXPORTING iv_has_header = abap_false
                                                                                 iv_csv_string = iv_first_line
                                                                       IMPORTING et_data       = <lt_table> ).
      CATCH zcx_wd_csv_too_many_columns
            zcx_wd_csv_too_few_columns.
        " these errors can probably be ignored, because the nr of cols was determined earlier
    ENDTRY.

* ----------------------------------------------------------------------
    LOOP AT <lt_table> ASSIGNING FIELD-SYMBOL(<ls>).
      LOOP AT it_components ASSIGNING FIELD-SYMBOL(<ls_component>).
        ASSIGN COMPONENT <ls_component>-name OF STRUCTURE <ls> TO FIELD-SYMBOL(<lv_col_name>).
        TRY.
            DATA(lv_abap_col_name) = it_name_mapping[ csv = to_upper( <lv_col_name> ) ]-abap.
          CATCH cx_sy_itab_line_not_found.
            lv_abap_col_name = <lv_col_name>.
        ENDTRY.
        lv_abap_col_name = to_upper( lv_abap_col_name ).
        APPEND VALUE #( name = lv_abap_col_name
                        type = <ls_component>-type
        ) TO lt_components.
      ENDLOOP.
      EXIT.
    ENDLOOP.

* ----------------------------------------------------------------------
    ro_struct_descr = cl_abap_structdescr=>create( lt_components ).

* ----------------------------------------------------------------------
  ENDMETHOD.


  METHOD get_column_name.
* ----------------------------------------------------------------------
    rv_col_name = |COL_{ iv_col_index }|.

* ----------------------------------------------------------------------
  ENDMETHOD.


ENDCLASS.
