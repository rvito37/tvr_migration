/*========================================================================
 * RH2TODBF.PRG - Convert RH2 report templates to DBF tables
 *
 * Parses RH2 binary files using RH2PARSE and writes the report
 * definitions into a set of relational DBF tables.
 *
 * Output tables:
 *   RPT_MAIN  - Report header/settings (1 row per report)
 *   RPT_FLD   - Report fields
 *   RPT_LINE  - Report line definitions
 *   RPT_LFLD  - Line field placements (fields within lines)
 *   RPT_DB    - Database definitions
 *   RPT_REL   - Database relations
 *   RPT_SORT  - Sort definitions
 *   RPT_LVL   - Group level definitions
 *========================================================================*/

* oRP main array indices (from RP.CH)
#define rpQUERY       1
#define rpFIELDS      2
#define rpREPORT      3
#define rpDATABASE    4
#define rpRUNTIME     5
#define rpLINES       6
#define rpLEVELS      7
#define rpSORTS       8
#define rpUSERFUNCS   9
#define rpFONTS      10

* rpQUERY sub-indices
#define rpQUERY_TEXT      1
#define rpQUERY_DESC      3

* rpFIELDS sub-indices
#define rpTABLE_NAME       1
#define rpFIELD_NAME       2
#define rpFIELD_TYPE       3
#define rpFIELD_LEN        4
#define rpFIELD_DEC        5
#define rpFIELD_LONGNAME   6
#define rpFIELD_TEXTBLOCK  8
#define rpFIELD_LEVEL     10
#define rpFIELD_PROCESS   11
#define rpFIELD_TOTAL_TYPE 12
#define rpFIELD_TOTAL_ACC 15

* rpREPORT sub-indices
#define rpREPORT_PAGELEN          22
#define rpREPORT_MARGIN_TOP       23
#define rpREPORT_MARGIN_LEFT      24
#define rpREPORT_MARGIN_BOTTOM    25
#define rpREPORT_MARGIN_RIGHT     26
#define rpREPORT_RECS_ACROSS      31
#define rpREPORT_COPIES           32
#define rpREPORT_LINES_PER_INCH   35
#define rpREPORT_CHARS_PER_INCH   36
#define rpREPORT_PAGE_ORIENT      39
#define rpREPORT_NAME             43
#define rpREPORT_SCOPE_LOW        48
#define rpREPORT_SCOPE_HIGH       49
#define rpREPORT_SCOPE_TYPE       50
#define rpREPORT_REC_WIDTH        61

* rpDATABASE sub-indices
#define rpDATABASE_TABLE       1
#define rpDATABASE_ALIAS       2
#define rpDATABASE_INDEX       3
#define rpDATABASE_REL         8
#define rpDATABASE_ORDER_NAME  9
#define rpDATABASE_RDDNAME    12

* rpREL sub-indices
#define rpREL_FROMALIAS    1
#define rpREL_TOALIAS      2
#define rpREL_SEEKTEXT     4
#define rpREL_MATCHTEXT    6
#define rpREL_TYPE         7

* rpLINE sub-indices
#define rpLFIELD_START     1
#define rpLFIELD_END       2
#define rpLFIELD_INDEX     3
#define rpLFIELD_FORMAT    4
#define rpLFIELD_JUSTIFY   5
#define rpLFIELD_AUTOTRIM  9
#define rpLFIELD_DEC      10
#define rpLINE_NEWPAGE    16
#define rpLINE_TYPE       18
#define rpLINE_LEVEL      19
#define rpLINE_ROW        20
#define rpLINE_TFILTER    26
#define rpLINE_COLOR      27
#define rpLINE_AUTOTRIM   24
#define rpLINE_HEIGHT     30

* rpLEVELS sub-indices
#define rpLEVEL_INDEX        1
#define rpLEVEL_DESC         2
#define rpLEVEL_LEVEL        3
#define rpLEVEL_ALLOW_BREAK  4
#define rpLEVEL_PAGE_RESET   5
#define rpLEVEL_SWAP_HEADER  6
#define rpLEVEL_SWAP_FOOTER  7
#define rpLEVEL_REPEAT_HDR   8

* rpSORTS sub-indices
#define rpSORT_RFO     1
#define rpSORT_ORDER   2


/*========================================================================*/
FUNCTION ConvertAllRH2( cRH2Dir, cDBFDir, nLogHan )
/*
 * Convert all RH2 files from cRH2Dir into DBF tables in cDBFDir.
 * nLogHan = optional log file handle for progress reporting
 */
LOCAL aFiles, nK, cFile, cRptId
LOCAL nTotal := 0, nOK := 0, nFail := 0

IF Right( cRH2Dir, 1 ) != Chr(92)
   cRH2Dir := cRH2Dir + Chr(92)
ENDIF
IF Right( cDBFDir, 1 ) != Chr(92)
   cDBFDir := cDBFDir + Chr(92)
ENDIF

* create output DBF tables
CreateDBFs( cDBFDir )

* find all RH2 files
aFiles := Directory( cRH2Dir + "*.RH2" )
nTotal := Len( aFiles )

IF nLogHan != NIL
   FWRITE( nLogHan, "Found " + LTrim(Str(nTotal)) + " RH2 files" + Chr(13)+Chr(10) )
ENDIF

FOR nK := 1 TO nTotal

   cFile  := aFiles[ nK ][ 1 ]
   cRptId := Upper( Left( cFile, At(".", cFile) - 1 ) )

   * convert this file
   IF ConvertOneRH2( cRH2Dir + cFile, cRptId )
      nOK++
   ELSE
      nFail++
      IF nLogHan != NIL
         FWRITE( nLogHan, "  FAILED: " + cFile + Chr(13)+Chr(10) )
      ENDIF
   ENDIF

   * progress every 20 files
   IF nLogHan != NIL .AND. ( nK % 20 == 0 .OR. nK == nTotal )
      FWRITE( nLogHan, "  [" + LTrim(Str(nK)) + "/" + LTrim(Str(nTotal)) + ;
         "] OK=" + LTrim(Str(nOK)) + " Fail=" + LTrim(Str(nFail)) + Chr(13)+Chr(10) )
   ENDIF

NEXT

* close all DBF tables
CloseDBFs()

IF nLogHan != NIL
   FWRITE( nLogHan, "Conversion complete: " + LTrim(Str(nOK)) + " OK, " + ;
      LTrim(Str(nFail)) + " failed out of " + LTrim(Str(nTotal)) + Chr(13)+Chr(10) )
ENDIF

RETURN nFail == 0
/*========================================================================*/

/*========================================================================*/
FUNCTION ConvertOneRH2( cFile, cRptId )
/*
 * Parse one RH2 file and write rows to all DBF tables.
 */
LOCAL oRP, aReport, aFields, aLines, aDBs, aLevels, aSorts
LOCAL aQuery
LOCAL nK, nJ, oLine, oField, oDB, oRel, oLevel, oSort
LOCAL aStarts, aEnds, aIdxs, aFmts, aJusts, aDecs, aTrims
LOCAL aRels

* parse the RH2 file
oRP := RH2_LoadReport( cFile )
IF oRP == NIL
   RETURN .F.
ENDIF

* validate: oRP should be an array with at least 8 elements
IF ValType( oRP ) != "A" .OR. Len( oRP ) < 8
   RETURN .F.
ENDIF

* extract main sections
aQuery   := RH2_ArrVal( oRP, rpQUERY )
aFields  := RH2_GetArr( RH2_ArrVal( oRP, rpFIELDS ) )
aReport  := RH2_GetArr( RH2_ArrVal( oRP, rpREPORT ) )
aDBs     := RH2_GetArr( RH2_ArrVal( oRP, rpDATABASE ) )
aLines   := RH2_GetArr( RH2_ArrVal( oRP, rpLINES ) )
aLevels  := RH2_GetArr( RH2_ArrVal( oRP, rpLEVELS ) )
aSorts   := RH2_GetArr( RH2_ArrVal( oRP, rpSORTS ) )
*------ RPT_MAIN ------
SELECT RPT_MAIN
APPEND BLANK
REPLACE RPT_ID     WITH cRptId
REPLACE RPT_NAME   WITH RH2_GetStr( RH2_ArrVal( aReport, rpREPORT_NAME ) )
REPLACE PAGE_LEN   WITH RH2_GetNum( RH2_ArrVal( aReport, rpREPORT_PAGELEN ) )
REPLACE PAGE_ORI   WITH RH2_GetNum( RH2_ArrVal( aReport, rpREPORT_PAGE_ORIENT ) )
REPLACE MARG_TOP   WITH RH2_GetNum( RH2_ArrVal( aReport, rpREPORT_MARGIN_TOP ) )
REPLACE MARG_LEFT  WITH RH2_GetNum( RH2_ArrVal( aReport, rpREPORT_MARGIN_LEFT ) )
REPLACE MARG_BOT   WITH RH2_GetNum( RH2_ArrVal( aReport, rpREPORT_MARGIN_BOTTOM ) )
REPLACE MARG_RIGHT WITH RH2_GetNum( RH2_ArrVal( aReport, rpREPORT_MARGIN_RIGHT ) )
REPLACE LPI        WITH RH2_GetNum( RH2_ArrVal( aReport, rpREPORT_LINES_PER_INCH ) )
REPLACE CPI        WITH RH2_GetNum( RH2_ArrVal( aReport, rpREPORT_CHARS_PER_INCH ) )
REPLACE REC_WIDTH  WITH RH2_GetNum( RH2_ArrVal( aReport, rpREPORT_REC_WIDTH ) )
REPLACE REC_ACROSS WITH RH2_GetNum( RH2_ArrVal( aReport, rpREPORT_RECS_ACROSS ) )
REPLACE COPIES     WITH RH2_GetNum( RH2_ArrVal( aReport, rpREPORT_COPIES ) )

* query
IF ValType( aQuery ) == "A" .AND. Len( aQuery ) >= 1
   REPLACE QUERY_TXT WITH RH2_GetStr( RH2_ArrVal( aQuery, rpQUERY_TEXT ) )
ENDIF

* scope
REPLACE SCOPE_LO  WITH RH2_GetStr( RH2_ArrVal( aReport, rpREPORT_SCOPE_LOW ) )
REPLACE SCOPE_HI  WITH RH2_GetStr( RH2_ArrVal( aReport, rpREPORT_SCOPE_HIGH ) )
REPLACE SCOPE_TYP WITH RH2_GetStr( RH2_ArrVal( aReport, rpREPORT_SCOPE_TYPE ) )

*------ RPT_FLD ------
SELECT RPT_FLD
FOR nK := 1 TO Len( aFields )
   oField := aFields[ nK ]
   IF ValType( oField ) != "A"
      LOOP
   ENDIF
   APPEND BLANK
   REPLACE RPT_ID     WITH cRptId
   REPLACE FLD_IDX    WITH nK
   REPLACE TBL_NAME   WITH RH2_GetStr( RH2_ArrVal( oField, rpTABLE_NAME ) )
   REPLACE FLD_NAME   WITH RH2_GetStr( RH2_ArrVal( oField, rpFIELD_NAME ) )
   REPLACE FLD_TYPE   WITH RH2_GetStr( RH2_ArrVal( oField, rpFIELD_TYPE ) )
   REPLACE FLD_LEN    WITH RH2_GetNum( RH2_ArrVal( oField, rpFIELD_LEN ) )
   REPLACE FLD_DEC    WITH RH2_GetNum( RH2_ArrVal( oField, rpFIELD_DEC ) )
   REPLACE FLD_LONG   WITH RH2_GetStr( RH2_ArrVal( oField, rpFIELD_LONGNAME ) )
   REPLACE FLD_EXPR   WITH RH2_GetStr( RH2_ArrVal( oField, rpFIELD_TEXTBLOCK ) )
   REPLACE FLD_LEVEL  WITH RH2_GetNum( RH2_ArrVal( oField, rpFIELD_LEVEL ) )
   REPLACE FLD_PROC   WITH RH2_GetNum( RH2_ArrVal( oField, rpFIELD_PROCESS ) )
   REPLACE FLD_TOTTYP WITH RH2_GetNum( RH2_ArrVal( oField, rpFIELD_TOTAL_TYPE ) )
   REPLACE FLD_TOTACC WITH RH2_GetNum( RH2_ArrVal( oField, rpFIELD_TOTAL_ACC ) )
NEXT

*------ RPT_LINE and RPT_LFLD ------
SELECT RPT_LINE
FOR nK := 1 TO Len( aLines )
   oLine := aLines[ nK ]
   IF ValType( oLine ) != "A"
      LOOP
   ENDIF

   * write line record
   SELECT RPT_LINE
   APPEND BLANK
   REPLACE RPT_ID     WITH cRptId
   REPLACE LINE_IDX   WITH nK
   REPLACE LINE_TYPE  WITH RH2_GetNum( RH2_ArrVal( oLine, rpLINE_TYPE ) )
   REPLACE LINE_LEVEL WITH RH2_GetNum( RH2_ArrVal( oLine, rpLINE_LEVEL ) )
   REPLACE LINE_ROW   WITH RH2_GetNum( RH2_ArrVal( oLine, rpLINE_ROW ) )
   REPLACE LINE_FILT  WITH RH2_GetStr( RH2_ArrVal( oLine, rpLINE_TFILTER ) )
   REPLACE LINE_TRIM  WITH RH2_GetLog( RH2_ArrVal( oLine, rpLINE_AUTOTRIM ) )
   REPLACE LINE_COLOR WITH RH2_GetNum( RH2_ArrVal( oLine, rpLINE_COLOR ) )
   REPLACE LINE_NEWPG WITH RH2_GetLog( RH2_ArrVal( oLine, rpLINE_NEWPAGE ) )
   REPLACE LINE_HGT   WITH RH2_GetNum( RH2_ArrVal( oLine, rpLINE_HEIGHT ) )

   * write line fields (parallel arrays within the line)
   aStarts := RH2_GetArr( RH2_ArrVal( oLine, rpLFIELD_START ) )
   aEnds   := RH2_GetArr( RH2_ArrVal( oLine, rpLFIELD_END ) )
   aIdxs   := RH2_GetArr( RH2_ArrVal( oLine, rpLFIELD_INDEX ) )
   aFmts   := RH2_GetArr( RH2_ArrVal( oLine, rpLFIELD_FORMAT ) )
   aJusts  := RH2_GetArr( RH2_ArrVal( oLine, rpLFIELD_JUSTIFY ) )
   aTrims  := RH2_GetArr( RH2_ArrVal( oLine, rpLFIELD_AUTOTRIM ) )
   aDecs   := RH2_GetArr( RH2_ArrVal( oLine, rpLFIELD_DEC ) )

   SELECT RPT_LFLD
   FOR nJ := 1 TO Len( aStarts )
      APPEND BLANK
      REPLACE RPT_ID    WITH cRptId
      REPLACE LINE_IDX  WITH nK
      REPLACE POS_IDX   WITH nJ
      REPLACE COL_START WITH RH2_GetNum( RH2_ArrVal( aStarts, nJ ) )
      REPLACE COL_END   WITH RH2_GetNum( RH2_ArrVal( aEnds,   nJ ) )
      REPLACE FLD_IDX   WITH RH2_GetNum( RH2_ArrVal( aIdxs,   nJ ) )
      REPLACE FLD_FMT   WITH RH2_GetNum( RH2_ArrVal( aFmts,   nJ ) )
      REPLACE FLD_JUST  WITH RH2_GetNum( RH2_ArrVal( aJusts,  nJ ) )
      REPLACE FLD_TRIM  WITH RH2_GetLog( RH2_ArrVal( aTrims,  nJ ) )
      REPLACE FLD_DEC   WITH RH2_GetNum( RH2_ArrVal( aDecs,   nJ ) )
   NEXT

NEXT

*------ RPT_DB and RPT_REL ------
SELECT RPT_DB
FOR nK := 1 TO Len( aDBs )
   oDB := aDBs[ nK ]
   IF ValType( oDB ) != "A"
      LOOP
   ENDIF

   SELECT RPT_DB
   APPEND BLANK
   REPLACE RPT_ID    WITH cRptId
   REPLACE DB_IDX    WITH nK
   REPLACE DB_TABLE  WITH RH2_GetStr( RH2_ArrVal( oDB, rpDATABASE_TABLE ) )
   REPLACE DB_ALIAS  WITH RH2_GetStr( RH2_ArrVal( oDB, rpDATABASE_ALIAS ) )
   REPLACE DB_INDEX  WITH RH2_GetStr( RH2_ArrVal( oDB, rpDATABASE_INDEX ) )
   REPLACE DB_ORDER  WITH RH2_GetStr( RH2_ArrVal( oDB, rpDATABASE_ORDER_NAME ) )
   REPLACE DB_RDD    WITH RH2_GetStr( RH2_ArrVal( oDB, rpDATABASE_RDDNAME ) )

   * relations for this database
   aRels := RH2_GetArr( RH2_ArrVal( oDB, rpDATABASE_REL ) )
   SELECT RPT_REL
   FOR nJ := 1 TO Len( aRels )
      oRel := aRels[ nJ ]
      IF ValType( oRel ) != "A"
         LOOP
      ENDIF
      APPEND BLANK
      REPLACE RPT_ID    WITH cRptId
      REPLACE DB_IDX    WITH nK
      REPLACE REL_IDX   WITH nJ
      REPLACE REL_FROM  WITH RH2_GetStr( RH2_ArrVal( oRel, rpREL_FROMALIAS ) )
      REPLACE REL_TO    WITH RH2_GetStr( RH2_ArrVal( oRel, rpREL_TOALIAS ) )
      REPLACE REL_EXPR  WITH RH2_GetStr( RH2_ArrVal( oRel, rpREL_SEEKTEXT ) )
      REPLACE REL_MATCH WITH RH2_GetStr( RH2_ArrVal( oRel, rpREL_MATCHTEXT ) )
      REPLACE REL_TYPE  WITH RH2_GetNum( RH2_ArrVal( oRel, rpREL_TYPE ) )
   NEXT

NEXT

*------ RPT_SORT ------
SELECT RPT_SORT
FOR nK := 1 TO Len( aSorts )
   oSort := aSorts[ nK ]
   IF ValType( oSort ) != "A"
      LOOP
   ENDIF
   APPEND BLANK
   REPLACE RPT_ID    WITH cRptId
   REPLACE SRT_IDX   WITH nK
   REPLACE SRT_FLD   WITH RH2_GetNum( RH2_ArrVal( oSort, rpSORT_RFO ) )
   REPLACE SRT_ORDER WITH RH2_GetStr( RH2_ArrVal( oSort, rpSORT_ORDER ) )
NEXT

*------ RPT_LVL ------
SELECT RPT_LVL
FOR nK := 1 TO Len( aLevels )
   oLevel := aLevels[ nK ]
   IF ValType( oLevel ) != "A"
      LOOP
   ENDIF
   APPEND BLANK
   REPLACE RPT_ID    WITH cRptId
   REPLACE LVL_IDX   WITH nK
   REPLACE LVL_FLD   WITH RH2_GetNum( RH2_ArrVal( oLevel, rpLEVEL_INDEX ) )
   REPLACE LVL_DESC  WITH RH2_GetStr( RH2_ArrVal( oLevel, rpLEVEL_DESC ) )
   REPLACE LVL_BREAK WITH RH2_GetLog( RH2_ArrVal( oLevel, rpLEVEL_ALLOW_BREAK ) )
   REPLACE LVL_PGRST WITH RH2_GetLog( RH2_ArrVal( oLevel, rpLEVEL_PAGE_RESET ) )
   REPLACE LVL_SWPHDR WITH RH2_GetLog( RH2_ArrVal( oLevel, rpLEVEL_SWAP_HEADER ) )
   REPLACE LVL_SWPFTR WITH RH2_GetLog( RH2_ArrVal( oLevel, rpLEVEL_SWAP_FOOTER ) )
   REPLACE LVL_RPTHDR WITH RH2_GetLog( RH2_ArrVal( oLevel, rpLEVEL_REPEAT_HDR ) )
NEXT

RETURN .T.
/*========================================================================*/

/*========================================================================*/
FUNCTION CreateDBFs( cDir )
/*
 * Create the 8 output DBF tables.
 */
LOCAL aStru

*--- RPT_MAIN ---
aStru := { ;
   { "RPT_ID",     "C", 12, 0 }, ;
   { "RPT_NAME",   "C", 40, 0 }, ;
   { "PAGE_LEN",   "N",  4, 0 }, ;
   { "PAGE_ORI",   "N",  2, 0 }, ;
   { "MARG_TOP",   "N",  4, 0 }, ;
   { "MARG_LEFT",  "N",  4, 0 }, ;
   { "MARG_BOT",   "N",  4, 0 }, ;
   { "MARG_RIGHT", "N",  4, 0 }, ;
   { "LPI",        "N",  2, 0 }, ;
   { "CPI",        "N",  2, 0 }, ;
   { "REC_WIDTH",  "N",  4, 0 }, ;
   { "REC_ACROSS", "N",  2, 0 }, ;
   { "COPIES",     "N",  2, 0 }, ;
   { "QUERY_TXT",  "C",200, 0 }, ;
   { "SCOPE_LO",   "C",100, 0 }, ;
   { "SCOPE_HI",   "C",100, 0 }, ;
   { "SCOPE_TYP",  "C", 20, 0 }  ;
}
DbCreate( cDir + "RPT_MAIN.DBF", aStru )
USE ( cDir + "RPT_MAIN.DBF" ) ALIAS RPT_MAIN NEW

*--- RPT_FLD ---
aStru := { ;
   { "RPT_ID",     "C", 12, 0 }, ;
   { "FLD_IDX",    "N",  4, 0 }, ;
   { "TBL_NAME",   "C", 20, 0 }, ;
   { "FLD_NAME",   "C", 20, 0 }, ;
   { "FLD_TYPE",   "C",  1, 0 }, ;
   { "FLD_LEN",    "N",  4, 0 }, ;
   { "FLD_DEC",    "N",  2, 0 }, ;
   { "FLD_LONG",   "C", 40, 0 }, ;
   { "FLD_EXPR",   "C",200, 0 }, ;
   { "FLD_LEVEL",  "N",  4, 0 }, ;
   { "FLD_PROC",   "N",  4, 0 }, ;
   { "FLD_TOTTYP", "N",  4, 0 }, ;
   { "FLD_TOTACC", "N",  4, 0 }  ;
}
DbCreate( cDir + "RPT_FLD.DBF", aStru )
USE ( cDir + "RPT_FLD.DBF" ) ALIAS RPT_FLD NEW

*--- RPT_LINE ---
aStru := { ;
   { "RPT_ID",     "C", 12, 0 }, ;
   { "LINE_IDX",   "N",  4, 0 }, ;
   { "LINE_TYPE",  "N",  2, 0 }, ;
   { "LINE_LEVEL", "N",  4, 0 }, ;
   { "LINE_ROW",   "N",  4, 0 }, ;
   { "LINE_FILT",  "C",200, 0 }, ;
   { "LINE_TRIM",  "L",  1, 0 }, ;
   { "LINE_COLOR", "N",  4, 0 }, ;
   { "LINE_NEWPG", "L",  1, 0 }, ;
   { "LINE_HGT",   "N",  4, 0 }  ;
}
DbCreate( cDir + "RPT_LINE.DBF", aStru )
USE ( cDir + "RPT_LINE.DBF" ) ALIAS RPT_LINE NEW

*--- RPT_LFLD ---
aStru := { ;
   { "RPT_ID",     "C", 12, 0 }, ;
   { "LINE_IDX",   "N",  4, 0 }, ;
   { "POS_IDX",    "N",  4, 0 }, ;
   { "COL_START",  "N",  4, 0 }, ;
   { "COL_END",    "N",  4, 0 }, ;
   { "FLD_IDX",    "N",  4, 0 }, ;
   { "FLD_FMT",    "N",  4, 0 }, ;
   { "FLD_JUST",   "N",  2, 0 }, ;
   { "FLD_TRIM",   "L",  1, 0 }, ;
   { "FLD_DEC",    "N",  4, 0 }  ;
}
DbCreate( cDir + "RPT_LFLD.DBF", aStru )
USE ( cDir + "RPT_LFLD.DBF" ) ALIAS RPT_LFLD NEW

*--- RPT_DB ---
aStru := { ;
   { "RPT_ID",     "C", 12, 0 }, ;
   { "DB_IDX",     "N",  4, 0 }, ;
   { "DB_TABLE",   "C", 30, 0 }, ;
   { "DB_ALIAS",   "C", 20, 0 }, ;
   { "DB_INDEX",   "C", 30, 0 }, ;
   { "DB_ORDER",   "C", 30, 0 }, ;
   { "DB_RDD",     "C", 12, 0 }  ;
}
DbCreate( cDir + "RPT_DB.DBF", aStru )
USE ( cDir + "RPT_DB.DBF" ) ALIAS RPT_DB NEW

*--- RPT_REL ---
aStru := { ;
   { "RPT_ID",     "C", 12, 0 }, ;
   { "DB_IDX",     "N",  4, 0 }, ;
   { "REL_IDX",    "N",  4, 0 }, ;
   { "REL_FROM",   "C", 20, 0 }, ;
   { "REL_TO",     "C", 20, 0 }, ;
   { "REL_EXPR",   "C",200, 0 }, ;
   { "REL_MATCH",  "C",200, 0 }, ;
   { "REL_TYPE",   "N",  4, 0 }  ;
}
DbCreate( cDir + "RPT_REL.DBF", aStru )
USE ( cDir + "RPT_REL.DBF" ) ALIAS RPT_REL NEW

*--- RPT_SORT ---
aStru := { ;
   { "RPT_ID",     "C", 12, 0 }, ;
   { "SRT_IDX",    "N",  4, 0 }, ;
   { "SRT_FLD",    "N",  4, 0 }, ;
   { "SRT_ORDER",  "C",  1, 0 }  ;
}
DbCreate( cDir + "RPT_SORT.DBF", aStru )
USE ( cDir + "RPT_SORT.DBF" ) ALIAS RPT_SORT NEW

*--- RPT_LVL ---
aStru := { ;
   { "RPT_ID",     "C", 12, 0 }, ;
   { "LVL_IDX",    "N",  4, 0 }, ;
   { "LVL_FLD",    "N",  4, 0 }, ;
   { "LVL_DESC",   "C", 40, 0 }, ;
   { "LVL_BREAK",  "L",  1, 0 }, ;
   { "LVL_PGRST",  "L",  1, 0 }, ;
   { "LVL_SWPHDR", "L",  1, 0 }, ;
   { "LVL_SWPFTR", "L",  1, 0 }, ;
   { "LVL_RPTHDR", "L",  1, 0 }  ;
}
DbCreate( cDir + "RPT_LVL.DBF", aStru )
USE ( cDir + "RPT_LVL.DBF" ) ALIAS RPT_LVL NEW

RETURN NIL
/*========================================================================*/

/*========================================================================*/
FUNCTION CloseDBFs()
/*
 * Close all output DBF tables.
 */
SELECT RPT_MAIN  ; USE
SELECT RPT_FLD   ; USE
SELECT RPT_LINE  ; USE
SELECT RPT_LFLD  ; USE
SELECT RPT_DB    ; USE
SELECT RPT_REL   ; USE
SELECT RPT_SORT  ; USE
SELECT RPT_LVL   ; USE
RETURN NIL
/*========================================================================*/
