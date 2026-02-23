/*========================================================================
 * RPTLOAD.PRG - Load report definition from RPT_DBF tables
 *
 * Replaces rpQuickLoad() / getarray().
 * Reads report structure from 8 DBF tables into simple Clipper arrays.
 *
 * Target: Clipper 5.3 (no Harbour-specific syntax)
 *
 * Author: Auto-generated for BMS TVR Migration
 *========================================================================*/

/*------------------------------------------------------------------------
 * Line type constants (from RP.CH)
 *------------------------------------------------------------------------*/
#DEFINE RP_TITLE         1
#DEFINE RP_PAGE_HEADER   2
#DEFINE RP_HEADER        3
#DEFINE RP_BODY          4
#DEFINE RP_FOOTER        5
#DEFINE RP_SUMMARY       6
#DEFINE RP_PAGE_FOOTER   7

/*------------------------------------------------------------------------
 * Total type constants
 *------------------------------------------------------------------------*/
#DEFINE RP_COUNT         1
#DEFINE RP_SUM           2
#DEFINE RP_AVERAGE       3
#DEFINE RP_LOWEST        4
#DEFINE RP_HIGHEST       5
#DEFINE RP_DEVIATION     6
#DEFINE RP_VARIANCE      7

/*------------------------------------------------------------------------
 * Process types
 *------------------------------------------------------------------------*/
#DEFINE RP_RUNNING       1
#DEFINE RP_PREPROCESSED  2

/*------------------------------------------------------------------------
 * Justification constants
 *------------------------------------------------------------------------*/
#DEFINE rpDEFAULT_JUSTIFY  0
#DEFINE rpLEFT_JUSTIFY     1
#DEFINE rpRIGHT_JUSTIFY    2
#DEFINE rpCENTER_JUSTIFY   3
#DEFINE rpFULL_JUSTIFY     4

/*------------------------------------------------------------------------
 * aRptDef array indices
 *------------------------------------------------------------------------*/
#DEFINE RD_ID        1
#DEFINE RD_SETTINGS  2
#DEFINE RD_FIELDS    3
#DEFINE RD_LINES     4
#DEFINE RD_LFLDS     5
#DEFINE RD_DBS       6
#DEFINE RD_RELS      7
#DEFINE RD_SORTS     8
#DEFINE RD_LEVELS    9

/*------------------------------------------------------------------------
 * aSettings sub-indices (from RPT_MAIN)
 *------------------------------------------------------------------------*/
#DEFINE RS_NAME       1
#DEFINE RS_PAGE_LEN   2
#DEFINE RS_PAGE_ORI   3
#DEFINE RS_MARG_TOP   4
#DEFINE RS_MARG_LEFT  5
#DEFINE RS_MARG_BOT   6
#DEFINE RS_MARG_RIGHT 7
#DEFINE RS_LPI        8
#DEFINE RS_CPI        9
#DEFINE RS_REC_WIDTH 10
#DEFINE RS_REC_ACROSS 11
#DEFINE RS_COPIES    12
#DEFINE RS_QUERY_TXT 13
#DEFINE RS_SCOPE_LO  14
#DEFINE RS_SCOPE_HI  15
#DEFINE RS_SCOPE_TYP 16

/*------------------------------------------------------------------------
 * Field sub-indices (from RPT_FLD)
 *------------------------------------------------------------------------*/
#DEFINE RF_TBL       1
#DEFINE RF_NAME      2
#DEFINE RF_TYPE      3
#DEFINE RF_LEN       4
#DEFINE RF_DEC       5
#DEFINE RF_LONG      6
#DEFINE RF_EXPR      7
#DEFINE RF_LEVEL     8
#DEFINE RF_PROC      9
#DEFINE RF_TOTTYP   10
#DEFINE RF_TOTACC   11
#DEFINE RF_BLOCK    12
#DEFINE RF_VAL      13

/*------------------------------------------------------------------------
 * Line sub-indices (from RPT_LINE)
 *------------------------------------------------------------------------*/
#DEFINE RL_TYPE      1
#DEFINE RL_LEVEL     2
#DEFINE RL_ROW       3
#DEFINE RL_FILTER    4
#DEFINE RL_TRIM      5
#DEFINE RL_COLOR     6
#DEFINE RL_NEWPG     7
#DEFINE RL_HEIGHT    8
#DEFINE RL_FBLOCK    9

/*------------------------------------------------------------------------
 * Line-field sub-indices (from RPT_LFLD)
 *------------------------------------------------------------------------*/
#DEFINE RLF_LINE     1
#DEFINE RLF_POS      2
#DEFINE RLF_COL_S    3
#DEFINE RLF_COL_E    4
#DEFINE RLF_FLD      5
#DEFINE RLF_FMT      6
#DEFINE RLF_JUST     7
#DEFINE RLF_TRIM     8
#DEFINE RLF_DEC      9

/*------------------------------------------------------------------------
 * DB sub-indices
 *------------------------------------------------------------------------*/
#DEFINE RDB_TABLE    1
#DEFINE RDB_ALIAS    2
#DEFINE RDB_INDEX    3
#DEFINE RDB_ORDER    4
#DEFINE RDB_RDD      5

/*------------------------------------------------------------------------
 * Level sub-indices
 *------------------------------------------------------------------------*/
#DEFINE RLV_FLD      1
#DEFINE RLV_DESC     2
#DEFINE RLV_BREAK    3
#DEFINE RLV_PGRST    4
#DEFINE RLV_SWPHDR   5
#DEFINE RLV_SWPFTR   6
#DEFINE RLV_RPTHDR   7

/*========================================================================*/
FUNCTION LoadReportDef( cRptId, cDBFDir )
/*
 * Load a report definition from DBF tables.
 *
 * Parameters:
 *   cRptId  - Report ID (e.g. "RPQC01V1")
 *   cDBFDir - Directory containing RPT_*.DBF files
 *
 * Returns: aRptDef array or NIL on failure
 */
LOCAL aRptDef
LOCAL cDir
LOCAL nSaveSele := SELECT()

* normalize directory
cDir := cDBFDir
IF Right( cDir, 1 ) != "\" .AND. Right( cDir, 1 ) != "/"
   cDir := cDir + "\"
ENDIF

* normalize ID - upper case, trimmed
cRptId := Upper( AllTrim( cRptId ) )

* create return structure
aRptDef := Array( 9 )
aRptDef[ RD_ID ]       := cRptId
aRptDef[ RD_SETTINGS ] := NIL
aRptDef[ RD_FIELDS ]   := {}
aRptDef[ RD_LINES ]    := {}
aRptDef[ RD_LFLDS ]    := {}
aRptDef[ RD_DBS ]      := {}
aRptDef[ RD_RELS ]     := {}
aRptDef[ RD_SORTS ]    := {}
aRptDef[ RD_LEVELS ]   := {}

* open DBF tables (shared, read-only)
IF !OpenRptDBFs( cDir )
   SELECT( nSaveSele )
   RETURN NIL
ENDIF

* load each section
LoadSettings( aRptDef, cRptId )
LoadFields(   aRptDef, cRptId )
LoadLines(    aRptDef, cRptId )
LoadLFlds(    aRptDef, cRptId )
LoadDBs(      aRptDef, cRptId )
LoadRels(     aRptDef, cRptId )
LoadSorts(    aRptDef, cRptId )
LoadLevels(   aRptDef, cRptId )

* compile field expressions into code blocks
CompileFields( aRptDef )

* compile line filter expressions
CompileLineFilters( aRptDef )

* close RPT tables
CloseRptDBFs()

* restore workarea
SELECT( nSaveSele )

IF aRptDef[ RD_SETTINGS ] == NIL
   RETURN NIL
ENDIF

RETURN aRptDef
/*========================================================================*/


/*========================================================================*/
STATIC FUNCTION OpenRptDBFs( cDir )
/*
 * Open all 8 RPT_*.DBF tables shared read-only.
 * Returns .T. if all opened OK, .F. otherwise.
 */

IF !File( cDir + "RPT_MAIN.DBF" )
   RETURN .F.
ENDIF

USE ( cDir + "RPT_MAIN.DBF" ) ALIAS RPTM_LD NEW SHARED READONLY
IF NetErr()
   RETURN .F.
ENDIF

USE ( cDir + "RPT_FLD.DBF"  ) ALIAS RPTF_LD NEW SHARED READONLY
IF NetErr()
   RPTM_LD->( DbCloseArea() )
   RETURN .F.
ENDIF

USE ( cDir + "RPT_LINE.DBF" ) ALIAS RPTL_LD NEW SHARED READONLY
IF NetErr()
   RPTF_LD->( DbCloseArea() )
   RPTM_LD->( DbCloseArea() )
   RETURN .F.
ENDIF

USE ( cDir + "RPT_LFLD.DBF" ) ALIAS RPTLF_LD NEW SHARED READONLY
IF NetErr()
   RPTL_LD->( DbCloseArea() )
   RPTF_LD->( DbCloseArea() )
   RPTM_LD->( DbCloseArea() )
   RETURN .F.
ENDIF

USE ( cDir + "RPT_DB.DBF"   ) ALIAS RPTD_LD NEW SHARED READONLY
IF NetErr()
   RPTLF_LD->( DbCloseArea() )
   RPTL_LD->(  DbCloseArea() )
   RPTF_LD->(  DbCloseArea() )
   RPTM_LD->(  DbCloseArea() )
   RETURN .F.
ENDIF

USE ( cDir + "RPT_REL.DBF"  ) ALIAS RPTR_LD NEW SHARED READONLY
IF NetErr()
   RPTD_LD->(  DbCloseArea() )
   RPTLF_LD->( DbCloseArea() )
   RPTL_LD->(  DbCloseArea() )
   RPTF_LD->(  DbCloseArea() )
   RPTM_LD->(  DbCloseArea() )
   RETURN .F.
ENDIF

USE ( cDir + "RPT_SORT.DBF" ) ALIAS RPTS_LD NEW SHARED READONLY
IF NetErr()
   RPTR_LD->(  DbCloseArea() )
   RPTD_LD->(  DbCloseArea() )
   RPTLF_LD->( DbCloseArea() )
   RPTL_LD->(  DbCloseArea() )
   RPTF_LD->(  DbCloseArea() )
   RPTM_LD->(  DbCloseArea() )
   RETURN .F.
ENDIF

USE ( cDir + "RPT_LVL.DBF"  ) ALIAS RPTLV_LD NEW SHARED READONLY
IF NetErr()
   RPTS_LD->(  DbCloseArea() )
   RPTR_LD->(  DbCloseArea() )
   RPTD_LD->(  DbCloseArea() )
   RPTLF_LD->( DbCloseArea() )
   RPTL_LD->(  DbCloseArea() )
   RPTF_LD->(  DbCloseArea() )
   RPTM_LD->(  DbCloseArea() )
   RETURN .F.
ENDIF

RETURN .T.
/*========================================================================*/


/*========================================================================*/
STATIC FUNCTION CloseRptDBFs()
IF Select( "RPTLV_LD" ) > 0
   RPTLV_LD->( DbCloseArea() )
ENDIF
IF Select( "RPTS_LD" ) > 0
   RPTS_LD->( DbCloseArea() )
ENDIF
IF Select( "RPTR_LD" ) > 0
   RPTR_LD->( DbCloseArea() )
ENDIF
IF Select( "RPTD_LD" ) > 0
   RPTD_LD->( DbCloseArea() )
ENDIF
IF Select( "RPTLF_LD" ) > 0
   RPTLF_LD->( DbCloseArea() )
ENDIF
IF Select( "RPTL_LD" ) > 0
   RPTL_LD->( DbCloseArea() )
ENDIF
IF Select( "RPTF_LD" ) > 0
   RPTF_LD->( DbCloseArea() )
ENDIF
IF Select( "RPTM_LD" ) > 0
   RPTM_LD->( DbCloseArea() )
ENDIF
RETURN NIL
/*========================================================================*/


/*========================================================================*/
STATIC FUNCTION LoadSettings( aRptDef, cRptId )
/*
 * Load report settings from RPT_MAIN table.
 */
LOCAL aSet
LOCAL cId := PadR( cRptId, 12 )

SELECT RPTM_LD
DbGoTop()
DO WHILE !Eof()
   IF AllTrim( RPTM_LD->RPT_ID ) == cRptId
      aSet := Array( 16 )
      aSet[ RS_NAME ]       := AllTrim( RPTM_LD->RPT_NAME )
      aSet[ RS_PAGE_LEN ]   := RPTM_LD->PAGE_LEN
      aSet[ RS_PAGE_ORI ]   := RPTM_LD->PAGE_ORI
      aSet[ RS_MARG_TOP ]   := RPTM_LD->MARG_TOP
      aSet[ RS_MARG_LEFT ]  := RPTM_LD->MARG_LEFT
      aSet[ RS_MARG_BOT ]   := RPTM_LD->MARG_BOT
      aSet[ RS_MARG_RIGHT ] := RPTM_LD->MARG_RIGHT
      aSet[ RS_LPI ]        := RPTM_LD->LPI
      aSet[ RS_CPI ]        := RPTM_LD->CPI
      aSet[ RS_REC_WIDTH ]  := RPTM_LD->REC_WIDTH
      aSet[ RS_REC_ACROSS ] := RPTM_LD->REC_ACROSS
      aSet[ RS_COPIES ]     := RPTM_LD->COPIES
      aSet[ RS_QUERY_TXT ]  := AllTrim( RPTM_LD->QUERY_TXT )
      aSet[ RS_SCOPE_LO ]   := AllTrim( RPTM_LD->SCOPE_LO )
      aSet[ RS_SCOPE_HI ]   := AllTrim( RPTM_LD->SCOPE_HI )
      aSet[ RS_SCOPE_TYP ]  := AllTrim( RPTM_LD->SCOPE_TYP )
      aRptDef[ RD_SETTINGS ] := aSet
      RETURN NIL
   ENDIF
   DbSkip()
ENDDO

RETURN NIL
/*========================================================================*/


/*========================================================================*/
STATIC FUNCTION LoadFields( aRptDef, cRptId )
/*
 * Load field definitions from RPT_FLD table.
 * Fields are loaded in order of FLD_IDX.
 */
LOCAL aFld

SELECT RPTF_LD
DbGoTop()
DO WHILE !Eof()
   IF AllTrim( RPTF_LD->RPT_ID ) == cRptId
      aFld := Array( 13 )
      aFld[ RF_TBL ]     := AllTrim( RPTF_LD->TBL_NAME )
      aFld[ RF_NAME ]    := AllTrim( RPTF_LD->FLD_NAME )
      aFld[ RF_TYPE ]    := AllTrim( RPTF_LD->FLD_TYPE )
      aFld[ RF_LEN ]     := RPTF_LD->FLD_LEN
      aFld[ RF_DEC ]     := RPTF_LD->FLD_DEC
      aFld[ RF_LONG ]    := AllTrim( RPTF_LD->FLD_LONG )
      aFld[ RF_EXPR ]    := AllTrim( RPTF_LD->FLD_EXPR )
      aFld[ RF_LEVEL ]   := RPTF_LD->FLD_LEVEL
      aFld[ RF_PROC ]    := RPTF_LD->FLD_PROC
      aFld[ RF_TOTTYP ]  := RPTF_LD->FLD_TOTTYP
      aFld[ RF_TOTACC ]  := RPTF_LD->FLD_TOTACC
      aFld[ RF_BLOCK ]   := NIL     // compiled later
      aFld[ RF_VAL ]     := NIL     // runtime accumulator
      AAdd( aRptDef[ RD_FIELDS ], aFld )
   ENDIF
   DbSkip()
ENDDO

RETURN NIL
/*========================================================================*/


/*========================================================================*/
STATIC FUNCTION LoadLines( aRptDef, cRptId )
/*
 * Load line definitions from RPT_LINE table.
 */
LOCAL aLine

SELECT RPTL_LD
DbGoTop()
DO WHILE !Eof()
   IF AllTrim( RPTL_LD->RPT_ID ) == cRptId
      aLine := Array( 9 )
      aLine[ RL_TYPE ]   := RPTL_LD->LINE_TYPE
      aLine[ RL_LEVEL ]  := RPTL_LD->LINE_LEVEL
      aLine[ RL_ROW ]    := RPTL_LD->LINE_ROW
      aLine[ RL_FILTER ] := AllTrim( RPTL_LD->LINE_FILT )
      aLine[ RL_TRIM ]   := RPTL_LD->LINE_TRIM
      aLine[ RL_COLOR ]  := RPTL_LD->LINE_COLOR
      aLine[ RL_NEWPG ]  := RPTL_LD->LINE_NEWPG
      aLine[ RL_HEIGHT ] := RPTL_LD->LINE_HGT
      aLine[ RL_FBLOCK ] := NIL     // compiled filter block
      AAdd( aRptDef[ RD_LINES ], aLine )
   ENDIF
   DbSkip()
ENDDO

RETURN NIL
/*========================================================================*/


/*========================================================================*/
STATIC FUNCTION LoadLFlds( aRptDef, cRptId )
/*
 * Load line-field placements from RPT_LFLD table.
 */
LOCAL aLF

SELECT RPTLF_LD
DbGoTop()
DO WHILE !Eof()
   IF AllTrim( RPTLF_LD->RPT_ID ) == cRptId
      aLF := Array( 9 )
      aLF[ RLF_LINE ]  := RPTLF_LD->LINE_IDX
      aLF[ RLF_POS ]   := RPTLF_LD->POS_IDX
      aLF[ RLF_COL_S ] := RPTLF_LD->COL_START
      aLF[ RLF_COL_E ] := RPTLF_LD->COL_END
      aLF[ RLF_FLD ]   := RPTLF_LD->FLD_IDX
      aLF[ RLF_FMT ]   := RPTLF_LD->FLD_FMT
      aLF[ RLF_JUST ]  := RPTLF_LD->FLD_JUST
      aLF[ RLF_TRIM ]  := RPTLF_LD->FLD_TRIM
      aLF[ RLF_DEC ]   := RPTLF_LD->FLD_DEC
      AAdd( aRptDef[ RD_LFLDS ], aLF )
   ENDIF
   DbSkip()
ENDDO

RETURN NIL
/*========================================================================*/


/*========================================================================*/
STATIC FUNCTION LoadDBs( aRptDef, cRptId )
/*
 * Load database definitions from RPT_DB table.
 */
LOCAL aDB

SELECT RPTD_LD
DbGoTop()
DO WHILE !Eof()
   IF AllTrim( RPTD_LD->RPT_ID ) == cRptId
      aDB := Array( 5 )
      aDB[ RDB_TABLE ] := AllTrim( RPTD_LD->DB_TABLE )
      aDB[ RDB_ALIAS ] := AllTrim( RPTD_LD->DB_ALIAS )
      aDB[ RDB_INDEX ] := AllTrim( RPTD_LD->DB_INDEX )
      aDB[ RDB_ORDER ] := AllTrim( RPTD_LD->DB_ORDER )
      aDB[ RDB_RDD ]   := AllTrim( RPTD_LD->DB_RDD )
      AAdd( aRptDef[ RD_DBS ], aDB )
   ENDIF
   DbSkip()
ENDDO

RETURN NIL
/*========================================================================*/


/*========================================================================*/
STATIC FUNCTION LoadRels( aRptDef, cRptId )
/*
 * Load relations from RPT_REL table.
 */
LOCAL aRel

SELECT RPTR_LD
DbGoTop()
DO WHILE !Eof()
   IF AllTrim( RPTR_LD->RPT_ID ) == cRptId
      aRel := Array( 5 )
      aRel[ 1 ] := AllTrim( RPTR_LD->REL_FROM )
      aRel[ 2 ] := AllTrim( RPTR_LD->REL_TO )
      aRel[ 3 ] := AllTrim( RPTR_LD->REL_EXPR )
      aRel[ 4 ] := AllTrim( RPTR_LD->REL_MATCH )
      aRel[ 5 ] := RPTR_LD->REL_TYPE
      AAdd( aRptDef[ RD_RELS ], aRel )
   ENDIF
   DbSkip()
ENDDO

RETURN NIL
/*========================================================================*/


/*========================================================================*/
STATIC FUNCTION LoadSorts( aRptDef, cRptId )
/*
 * Load sort definitions from RPT_SORT table.
 */
LOCAL aSort

SELECT RPTS_LD
DbGoTop()
DO WHILE !Eof()
   IF AllTrim( RPTS_LD->RPT_ID ) == cRptId
      aSort := Array( 2 )
      aSort[ 1 ] := RPTS_LD->SRT_FLD
      aSort[ 2 ] := AllTrim( RPTS_LD->SRT_ORDER )
      AAdd( aRptDef[ RD_SORTS ], aSort )
   ENDIF
   DbSkip()
ENDDO

RETURN NIL
/*========================================================================*/


/*========================================================================*/
STATIC FUNCTION LoadLevels( aRptDef, cRptId )
/*
 * Load group level definitions from RPT_LVL table.
 */
LOCAL aLvl

SELECT RPTLV_LD
DbGoTop()
DO WHILE !Eof()
   IF AllTrim( RPTLV_LD->RPT_ID ) == cRptId
      aLvl := Array( 7 )
      aLvl[ RLV_FLD ]    := RPTLV_LD->LVL_FLD
      aLvl[ RLV_DESC ]   := AllTrim( RPTLV_LD->LVL_DESC )
      aLvl[ RLV_BREAK ]  := RPTLV_LD->LVL_BREAK
      aLvl[ RLV_PGRST ]  := RPTLV_LD->LVL_PGRST
      aLvl[ RLV_SWPHDR ] := RPTLV_LD->LVL_SWPHDR
      aLvl[ RLV_SWPFTR ] := RPTLV_LD->LVL_SWPFTR
      aLvl[ RLV_RPTHDR ] := RPTLV_LD->LVL_RPTHDR
      AAdd( aRptDef[ RD_LEVELS ], aLvl )
   ENDIF
   DbSkip()
ENDDO

RETURN NIL
/*========================================================================*/


/*========================================================================*/
STATIC FUNCTION CompileFields( aRptDef )
/*
 * Compile field expression text blocks into code blocks.
 * This is equivalent to what rpQuickLoad does after getarray().
 *
 * For each field, if it has an expression like "{||DBFNAME->FIELDNAME}",
 * macro-compile it into a code block.
 * For __TEXT__ fields, the "long name" IS the value (static text).
 * For _VIRTUAL_ fields (calc/total), code block evaluates the expression.
 */
LOCAL nK, aFld, cExpr

FOR nK := 1 TO Len( aRptDef[ RD_FIELDS ] )

   aFld := aRptDef[ RD_FIELDS ][ nK ]

   * initialize runtime value based on type
   IF aFld[ RF_TYPE ] == "N"
      aFld[ RF_VAL ] := 0
   ELSEIF aFld[ RF_TYPE ] == "D"
      aFld[ RF_VAL ] := CToD("")
   ELSEIF aFld[ RF_TYPE ] == "L"
      aFld[ RF_VAL ] := .F.
   ELSE
      aFld[ RF_VAL ] := ""
   ENDIF

   * compile expression into code block
   cExpr := aFld[ RF_EXPR ]
   IF !Empty( cExpr )
      * expressions are stored as text like "{||TABLE->FIELD}"
      * or "{|oRP|...}" — macro-compile them
      aFld[ RF_BLOCK ] := &( cExpr )
   ELSEIF aFld[ RF_TBL ] == "__TEXT__"
      * text fields: the long name IS the value
      aFld[ RF_BLOCK ] := NIL
      aFld[ RF_VAL ]   := aFld[ RF_LONG ]
   ELSE
      * fallback: try TABLE->FIELD direct
      IF !Empty( aFld[ RF_TBL ] ) .AND. aFld[ RF_TBL ] != "_VIRTUAL_"
         cExpr := "{||" + AllTrim( aFld[ RF_TBL ] ) + "->" + AllTrim( aFld[ RF_NAME ] ) + "}"
         aFld[ RF_BLOCK ] := &( cExpr )
      ELSE
         aFld[ RF_BLOCK ] := NIL
      ENDIF
   ENDIF

NEXT

RETURN NIL
/*========================================================================*/


/*========================================================================*/
STATIC FUNCTION CompileLineFilters( aRptDef )
/*
 * Compile line filter expressions into code blocks.
 * Filter text is stored as "{||.T.}" or similar.
 */
LOCAL nK, aLine, cFilt

FOR nK := 1 TO Len( aRptDef[ RD_LINES ] )

   aLine := aRptDef[ RD_LINES ][ nK ]
   cFilt := aLine[ RL_FILTER ]

   IF !Empty( cFilt )
      aLine[ RL_FBLOCK ] := &( cFilt )
   ELSE
      aLine[ RL_FBLOCK ] := {|| .T. }
   ENDIF

NEXT

RETURN NIL
/*========================================================================*/


/*========================================================================*/
FUNCTION GetLFldsByLine( aRptDef, nLineIdx )
/*
 * Get all line-field placements for a given line index.
 * Returns an array of aLF sub-arrays.
 */
LOCAL aResult := {}
LOCAL nK, aLF

FOR nK := 1 TO Len( aRptDef[ RD_LFLDS ] )
   aLF := aRptDef[ RD_LFLDS ][ nK ]
   IF aLF[ RLF_LINE ] == nLineIdx
      AAdd( aResult, aLF )
   ENDIF
NEXT

RETURN aResult
/*========================================================================*/


/*========================================================================*/
FUNCTION GetLinesByType( aRptDef, nType, nLevel )
/*
 * Get all lines of a specific type (and optional level for headers/footers).
 * Returns array of { line_array, line_index } pairs.
 */
LOCAL aResult := {}
LOCAL nK, aLine

FOR nK := 1 TO Len( aRptDef[ RD_LINES ] )
   aLine := aRptDef[ RD_LINES ][ nK ]
   IF aLine[ RL_TYPE ] == nType
      IF nLevel == NIL .OR. aLine[ RL_LEVEL ] == nLevel
         AAdd( aResult, { aLine, nK } )
      ENDIF
   ENDIF
NEXT

RETURN aResult
/*========================================================================*/


/*========================================================================*/
FUNCTION RptRecWidth( aRptDef )
/*
 * Get the effective record width (line length) for text output.
 * Falls back to margin-based calculation if not stored.
 */
LOCAL aSet := aRptDef[ RD_SETTINGS ]
LOCAL nWidth

IF aSet == NIL
   RETURN 80
ENDIF

nWidth := aSet[ RS_REC_WIDTH ]
IF nWidth == 0 .OR. nWidth == NIL
   * calculate from margins
   nWidth := 80  // default
   IF aSet[ RS_PAGE_ORI ] == 2  // landscape
      nWidth := 132
   ENDIF
ENDIF

RETURN nWidth
/*========================================================================*/
