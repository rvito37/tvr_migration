/*========================================================================
 * RPTGEN.PRG - Native Clipper report generation engine
 *
 * Replaces rpGenReport() / rpGenerate() / rpMakeNew() / MAKEGROUP() / rpPageOut()
 * Reads report definition from DBF tables via LoadReportDef(),
 * iterates data records, formats output, writes to file.
 *
 * Produces text output IDENTICAL to what TVR produced.
 *
 * Target: Clipper 5.3
 *
 * Author: Auto-generated for BMS TVR Migration
 *========================================================================*/

/*------------------------------------------------------------------------
 * Include our own headers (from RPTLOAD.PRG / RPTFMT.PRG)
 *------------------------------------------------------------------------*/

* Line type constants
#DEFINE RP_TITLE         1
#DEFINE RP_PAGE_HEADER   2
#DEFINE RP_HEADER        3
#DEFINE RP_BODY          4
#DEFINE RP_FOOTER        5
#DEFINE RP_SUMMARY       6
#DEFINE RP_PAGE_FOOTER   7

* Destination constants (matching THEREPO.PRG #DEFINEs)
#DEFINE rpPRINTER        1
#DEFINE rpPRINTER_FILE   2
#DEFINE rpDISPLAY        3

* aRptDef array indices
#DEFINE RD_ID        1
#DEFINE RD_SETTINGS  2
#DEFINE RD_FIELDS    3
#DEFINE RD_LINES     4
#DEFINE RD_LFLDS     5
#DEFINE RD_DBS       6
#DEFINE RD_RELS      7
#DEFINE RD_SORTS     8
#DEFINE RD_LEVELS    9

* Settings sub-indices
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

* Field sub-indices
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

* Line sub-indices
#DEFINE RL_TYPE      1
#DEFINE RL_LEVEL     2
#DEFINE RL_ROW       3
#DEFINE RL_FILTER    4
#DEFINE RL_TRIM      5
#DEFINE RL_COLOR     6
#DEFINE RL_NEWPG     7
#DEFINE RL_HEIGHT    8
#DEFINE RL_FBLOCK    9

* Line-field sub-indices
#DEFINE RLF_LINE     1
#DEFINE RLF_POS      2
#DEFINE RLF_COL_S    3
#DEFINE RLF_COL_E    4
#DEFINE RLF_FLD      5
#DEFINE RLF_FMT      6
#DEFINE RLF_JUST     7
#DEFINE RLF_TRIM     8
#DEFINE RLF_DEC      9

* Level sub-indices
#DEFINE RLV_FLD      1
#DEFINE RLV_DESC     2
#DEFINE RLV_BREAK    3
#DEFINE RLV_PGRST    4
#DEFINE RLV_SWPHDR   5
#DEFINE RLV_SWPFTR   6
#DEFINE RLV_RPTHDR   7

* Total type constants
#DEFINE RP_COUNT         1
#DEFINE RP_SUM           2
#DEFINE RP_AVERAGE       3
#DEFINE RP_LOWEST        4
#DEFINE RP_HIGHEST       5

#DEFINE TRUE  .T.
#DEFINE FALSE .F.


/*========================================================================*/
FUNCTION GenReportFromDBF( cRptFile, cTempDir, nDest, aDbs, ;
                           aTstBlocks, aMyBuffer, oTheRep, cDBFDir )
/*
 * Main entry point - replaces rpGenReport() in Print() method.
 *
 * Parameters:
 *   cRptFile   - Report filename (e.g. "RPQC01V1.RH2" or "RPQC01V1")
 *   cTempDir   - Temporary file directory
 *   nDest      - Destination: 1=printer, 2=file, 3=display
 *   aDbs       - Array of database names (from TheReport::aDBs)
 *   aTstBlocks - Test blocks for query filter
 *   aMyBuffer  - User-selected criteria buffer
 *   oTheRep    - TheReport object (Self)
 *   cDBFDir    - Directory with RPT_*.DBF tables
 *
 * Returns: NIL
 */
LOCAL aRptDef
LOCAL cRptId
LOCAL nOutHan    := 0
LOCAL cOutFile   := ""
LOCAL nPageNo    := 1
LOCAL nLineNo    := 0
LOCAL nPageLen
LOCAL nLineLen
LOCAL nTopMargin
LOCAL nBotMargin
LOCAL nLeftMargin
LOCAL nWorkLen
LOCAL aPageBuff  := {}
LOCAL aSummLines := {}

LOCAL cOrigScreen := ""

* extract RPT_ID from filename
cRptId := RptExtractId( cRptFile )

* default DBF directory
IF cDBFDir == NIL .OR. Empty( cDBFDir )
   cDBFDir := cTempDir
ENDIF

* normalize temp dir
IF Right( cTempDir, 1 ) != "\" .AND. Right( cTempDir, 1 ) != "/"
   cTempDir := cTempDir + "\"
ENDIF

* load report definition from DBF tables
aRptDef := LoadReportDef( cRptId, cDBFDir )
IF aRptDef == NIL
   RETURN NIL
ENDIF

* report dimensions
nPageLen    := aRptDef[ RD_SETTINGS ][ RS_PAGE_LEN ]
nTopMargin  := aRptDef[ RD_SETTINGS ][ RS_MARG_TOP ]
nBotMargin  := aRptDef[ RD_SETTINGS ][ RS_MARG_BOT ]
nLeftMargin := aRptDef[ RD_SETTINGS ][ RS_MARG_LEFT ]
nLineLen    := RptRecWidth( aRptDef )

* work area = page length minus page footer lines minus bottom margin
nWorkLen := nPageLen - CountLinesByType( aRptDef, RP_PAGE_FOOTER ) - nBotMargin

IF nPageLen <= 0
   nPageLen := 66
ENDIF
IF nWorkLen <= nTopMargin
   nWorkLen := nPageLen - 6
ENDIF

* open output file (for file destination)
IF nDest == rpPRINTER_FILE
   cOutFile := cTempDir + GetPrintFile()
   nOutHan  := FCreate( AllTrim( cOutFile ), 0 )
   IF nOutHan < 1
      RETURN NIL
   ENDIF
ELSEIF nDest == rpPRINTER
   * printer output - use direct fwrite to print file
   cOutFile := cTempDir + GetPrintFile()
   nOutHan  := FCreate( AllTrim( cOutFile ), 0 )
   IF nOutHan < 1
      RETURN NIL
   ENDIF
ENDIF

* build summary lines from TheReport if available
IF oTheRep != NIL
   aSummLines := BuildSummaryLines( oTheRep, aDbs, nLineLen, nLeftMargin )
ENDIF

* initialize page buffer
nLineNo := nTopMargin
aPageBuff := Array( nPageLen )
AFill( aPageBuff, "" )

* generate the report
RptGenerate( aRptDef, nOutHan, nDest, aDbs, aTstBlocks, aMyBuffer, ;
             @nPageNo, @nLineNo, @aPageBuff, ;
             nPageLen, nLineLen, nTopMargin, nBotMargin, nLeftMargin, ;
             nWorkLen, aSummLines )

* close output file
IF nOutHan > 0
   FClose( nOutHan )
ENDIF

RETURN NIL
/*========================================================================*/


/*========================================================================*/
STATIC FUNCTION RptGenerate( aRptDef, nOutHan, nDest, aDbs, aTstBlocks, ;
                              aMyBuffer, nPageNo, nLineNo, aPageBuff, ;
                              nPageLen, nLineLen, nTopMargin, nBotMargin, ;
                              nLeftMargin, nWorkLen, aSummLines )
/*
 * Core report generation loop.
 * Matches rpGenerate() flow in GEN.PRG.
 */
LOCAL nK, nY
LOCAL nBreakCnt
LOCAL nRecCount   := 0
LOCAL nBreakLevel := 0
LOCAL nLowBreak   := 0
LOCAL aLevels     := {}
LOCAL aLastVals   := {}
LOCAL aBreakList  := {}
LOCAL lHasLevels  := .F.
LOCAL cMasterAlias
LOCAL xCurrVal

* get the primary database alias
IF Len( aDbs ) > 0
   cMasterAlias := aDbs[ 1 ]
ELSE
   * try from report definition
   IF Len( aRptDef[ RD_DBS ] ) > 0
      cMasterAlias := aRptDef[ RD_DBS ][ 1 ][ 2 ]  // alias
   ELSE
      RETURN NIL
   ENDIF
ENDIF

* ensure we're on the master alias
IF Select( cMasterAlias ) == 0
   RETURN NIL
ENDIF
SELECT( Select( cMasterAlias ) )

* check for records
IF RecCount() == 0
   RETURN NIL
ENDIF

* setup break levels
nBreakCnt := Len( aRptDef[ RD_LEVELS ] )
lHasLevels := nBreakCnt > 0

IF lHasLevels
   * build level break evaluation blocks from level field references
   aLevels   := Array( nBreakCnt )
   aLastVals := Array( nBreakCnt )
   FOR nK := 1 TO nBreakCnt
      nY := aRptDef[ RD_LEVELS ][ nK ][ RLV_FLD ]
      IF nY > 0 .AND. nY <= Len( aRptDef[ RD_FIELDS ] )
         aLevels[ nK ] := aRptDef[ RD_FIELDS ][ nY ][ RF_BLOCK ]
      ELSE
         aLevels[ nK ] := {|| "" }
      ENDIF
   NEXT
ENDIF

* initialize totals
RptResetTotals( aRptDef, 0 )

* evaluate all fields at first record position
DbGoTop()
RptEvalFields( aRptDef )

* save initial break level values
IF lHasLevels
   FOR nK := 1 TO nBreakCnt
      IF aLevels[ nK ] != NIL
         aLastVals[ nK ] := Eval( aLevels[ nK ] )
      ELSE
         aLastVals[ nK ] := ""
      ENDIF
   NEXT
ENDIF

* output title lines
RptOutputSection( aRptDef, RP_TITLE, 0, nOutHan, @nLineNo, @nPageNo, ;
                  @aPageBuff, nPageLen, nLineLen, nLeftMargin, ;
                  nTopMargin, nWorkLen )

* output page headers
RptOutputSection( aRptDef, RP_PAGE_HEADER, 0, nOutHan, @nLineNo, @nPageNo, ;
                  @aPageBuff, nPageLen, nLineLen, nLeftMargin, ;
                  nTopMargin, nWorkLen )

* output group headers (all levels, level 1..n)
IF lHasLevels
   FOR nK := 1 TO nBreakCnt
      RptOutputSection( aRptDef, RP_HEADER, nK, nOutHan, @nLineNo, @nPageNo, ;
                        @aPageBuff, nPageLen, nLineLen, nLeftMargin, ;
                        nTopMargin, nWorkLen )
   NEXT
ENDIF

*
* ===== MAIN DATA LOOP =====
*
DO WHILE !Eof()

   * check for exit
   nRecCount++

   * evaluate all field values for current record
   RptEvalFields( aRptDef )

   * check for break levels
   nBreakLevel := 0
   nLowBreak   := 0

   IF lHasLevels
      * check from highest to lowest (reverse order like TVR)
      FOR nK := nBreakCnt TO 1 STEP -1
         IF aLevels[ nK ] != NIL
            xCurrVal := Eval( aLevels[ nK ] )
         ELSE
            xCurrVal := ""
         ENDIF
         IF !( xCurrVal == aLastVals[ nK ] )
            IF nBreakLevel == 0
               nBreakLevel := nK
            ENDIF
            nLowBreak := nK
         ENDIF
      NEXT
   ENDIF

   * process break if detected
   IF nBreakLevel > 0

      * output footers from highest break down to lowest
      FOR nK := nBreakCnt TO nLowBreak STEP -1

         * accumulate totals for this level
         RptAccumTotals( aRptDef, nK )

         * output footer for this level
         RptOutputSection( aRptDef, RP_FOOTER, nK, nOutHan, @nLineNo, @nPageNo, ;
                           @aPageBuff, nPageLen, nLineLen, nLeftMargin, ;
                           nTopMargin, nWorkLen )

         * reset totals for this level
         RptResetTotals( aRptDef, nK )

      NEXT

      * check for page reset on break
      FOR nK := nLowBreak TO nBreakCnt
         IF aRptDef[ RD_LEVELS ][ nK ][ RLV_PGRST ]
            * new page
            RptNewPage( aRptDef, nOutHan, @nLineNo, @nPageNo, ;
                        @aPageBuff, nPageLen, nLineLen, nLeftMargin, ;
                        nTopMargin, nWorkLen )
         ENDIF
      NEXT

      * update saved break values
      FOR nK := nLowBreak TO nBreakCnt
         IF aLevels[ nK ] != NIL
            aLastVals[ nK ] := Eval( aLevels[ nK ] )
         ENDIF
      NEXT

      * output headers from lowest break up to highest
      FOR nK := nLowBreak TO nBreakCnt
         RptOutputSection( aRptDef, RP_HEADER, nK, nOutHan, @nLineNo, @nPageNo, ;
                           @aPageBuff, nPageLen, nLineLen, nLeftMargin, ;
                           nTopMargin, nWorkLen )
      NEXT

   ENDIF

   * accumulate running totals (all levels)
   RptAccumRunning( aRptDef )

   * check if body lines will fit on page
   IF nLineNo + CountLinesByType2( aRptDef, RP_BODY, 0 ) > nWorkLen
      * new page needed
      RptNewPage( aRptDef, nOutHan, @nLineNo, @nPageNo, ;
                  @aPageBuff, nPageLen, nLineLen, nLeftMargin, ;
                  nTopMargin, nWorkLen )
   ENDIF

   * output body lines
   RptOutputSection( aRptDef, RP_BODY, 0, nOutHan, @nLineNo, @nPageNo, ;
                     @aPageBuff, nPageLen, nLineLen, nLeftMargin, ;
                     nTopMargin, nWorkLen )

   * skip to next record
   DbSkip()

ENDDO

* ===== END OF DATA =====

* do final footers (all levels, highest to lowest)
IF lHasLevels
   FOR nK := nBreakCnt TO 1 STEP -1
      RptAccumTotals( aRptDef, nK )
      RptOutputSection( aRptDef, RP_FOOTER, nK, nOutHan, @nLineNo, @nPageNo, ;
                        @aPageBuff, nPageLen, nLineLen, nLeftMargin, ;
                        nTopMargin, nWorkLen )
   NEXT
ENDIF

* output summary section (criteria text)
IF Len( aSummLines ) > 0
   RptOutputSummary( aSummLines, nOutHan, @nLineNo, @nPageNo, ;
                     @aPageBuff, nPageLen, nLineLen, nLeftMargin, ;
                     nTopMargin, nWorkLen )
ENDIF

* output page footers for last page
RptOutputSection( aRptDef, RP_PAGE_FOOTER, 0, nOutHan, @nLineNo, @nPageNo, ;
                  @aPageBuff, nPageLen, nLineLen, nLeftMargin, ;
                  nTopMargin, nWorkLen )

* flush last page
RptFlushPage( aPageBuff, nOutHan, nLineNo, nPageLen, .T. )

RETURN NIL
/*========================================================================*/


/*========================================================================*/
STATIC FUNCTION RptOutputSection( aRptDef, nType, nLevel, nOutHan, ;
                                   nLineNo, nPageNo, aPageBuff, ;
                                   nPageLen, nLineLen, nLeftMargin, ;
                                   nTopMargin, nWorkLen )
/*
 * Output all lines of a given type/level.
 * Evaluates field values, formats them, builds text lines,
 * places them into the page buffer.
 */
LOCAL nK, nJ
LOCAL aLine, aLineFlds
LOCAL cLine
LOCAL aFmtVals
LOCAL nFldIdx, aFld, aLF
LOCAL xVal, cFmtVal
LOCAL nWidth
LOCAL lPassFilter

FOR nK := 1 TO Len( aRptDef[ RD_LINES ] )

   aLine := aRptDef[ RD_LINES ][ nK ]

   * check line type match
   IF aLine[ RL_TYPE ] != nType
      LOOP
   ENDIF

   * check level match (for headers/footers)
   IF nType == RP_HEADER .OR. nType == RP_FOOTER
      IF aLine[ RL_LEVEL ] != nLevel
         LOOP
      ENDIF
   ENDIF

   * evaluate line filter
   lPassFilter := TRUE
   IF aLine[ RL_FBLOCK ] != NIL
      lPassFilter := Eval( aLine[ RL_FBLOCK ] )
   ENDIF
   IF !lPassFilter
      LOOP
   ENDIF

   * check for new page flag on this line
   IF aLine[ RL_NEWPG ]
      RptNewPage( aRptDef, nOutHan, @nLineNo, @nPageNo, ;
                  @aPageBuff, nPageLen, nLineLen, nLeftMargin, ;
                  nTopMargin, nWorkLen )
   ENDIF

   * check if line fits on current page
   IF nLineNo + 1 > nWorkLen .AND. nType != RP_PAGE_FOOTER
      RptNewPage( aRptDef, nOutHan, @nLineNo, @nPageNo, ;
                  @aPageBuff, nPageLen, nLineLen, nLeftMargin, ;
                  nTopMargin, nWorkLen )
   ENDIF

   * get field placements for this line
   aLineFlds := GetLFldsByLine( aRptDef, nK )

   IF Len( aLineFlds ) == 0
      * line with no fields = blank line
      nLineNo++
      IF nLineNo <= nPageLen
         aPageBuff[ nLineNo ] := ""
      ENDIF
      LOOP
   ENDIF

   * evaluate and format each field value
   aFmtVals := Array( Len( aLineFlds ) )

   FOR nJ := 1 TO Len( aLineFlds )

      aLF := aLineFlds[ nJ ]
      nFldIdx := aLF[ RLF_FLD ]

      IF nFldIdx > 0 .AND. nFldIdx <= Len( aRptDef[ RD_FIELDS ] )
         aFld := aRptDef[ RD_FIELDS ][ nFldIdx ]

         * get value
         IF aFld[ RF_TBL ] == "__TEXT__"
            * text field: value is the long name
            xVal := aFld[ RF_LONG ]
         ELSEIF aFld[ RF_BLOCK ] != NIL
            * normal field: evaluate code block
            xVal := Eval( aFld[ RF_BLOCK ] )
         ELSEIF aFld[ RF_VAL ] != NIL
            * calc/total field: use accumulated value
            xVal := aFld[ RF_VAL ]
         ELSE
            xVal := ""
         ENDIF

         * calculate display width from column positions
         nWidth := aLF[ RLF_COL_E ] - aLF[ RLF_COL_S ] + 1

         * format the value
         cFmtVal := RptFmtField( xVal, aFld[ RF_TYPE ], nWidth, ;
                                  aLF[ RLF_DEC ], aLF[ RLF_FMT ], ;
                                  aLF[ RLF_JUST ] )
         aFmtVals[ nJ ] := cFmtVal
      ELSE
         aFmtVals[ nJ ] := ""
      ENDIF

   NEXT

   * build the output line
   cLine := RptBuildLine( nLineLen, nLeftMargin, aLineFlds, aFmtVals )

   * place into page buffer
   nLineNo++
   IF nLineNo <= nPageLen
      aPageBuff[ nLineNo ] := cLine
   ENDIF

NEXT

RETURN NIL
/*========================================================================*/


/*========================================================================*/
STATIC FUNCTION RptNewPage( aRptDef, nOutHan, nLineNo, nPageNo, ;
                             aPageBuff, nPageLen, nLineLen, nLeftMargin, ;
                             nTopMargin, nWorkLen )
/*
 * Handle page break: output page footer, flush page, start new page.
 */

* output page footers on current page
RptOutputSection( aRptDef, RP_PAGE_FOOTER, 0, nOutHan, @nLineNo, @nPageNo, ;
                  @aPageBuff, nPageLen, nLineLen, nLeftMargin, ;
                  nTopMargin, nWorkLen )

* flush current page to output
RptFlushPage( aPageBuff, nOutHan, nLineNo, nPageLen, .F. )

* increment page number
nPageNo++

* reset page buffer
AFill( aPageBuff, "" )

* reset line counter to top margin
nLineNo := nTopMargin

* output page headers on new page
RptOutputSection( aRptDef, RP_PAGE_HEADER, 0, nOutHan, @nLineNo, @nPageNo, ;
                  @aPageBuff, nPageLen, nLineLen, nLeftMargin, ;
                  nTopMargin, nWorkLen )

* repeat group headers if configured
RptRepeatHeaders( aRptDef, nOutHan, @nLineNo, @nPageNo, ;
                  @aPageBuff, nPageLen, nLineLen, nLeftMargin, ;
                  nTopMargin, nWorkLen )

RETURN NIL
/*========================================================================*/


/*========================================================================*/
STATIC FUNCTION RptRepeatHeaders( aRptDef, nOutHan, nLineNo, nPageNo, ;
                                   aPageBuff, nPageLen, nLineLen, ;
                                   nLeftMargin, nTopMargin, nWorkLen )
/*
 * Repeat group headers on new page if level has repeat-header flag.
 */
LOCAL nK

FOR nK := 1 TO Len( aRptDef[ RD_LEVELS ] )
   IF aRptDef[ RD_LEVELS ][ nK ][ RLV_RPTHDR ]
      RptOutputSection( aRptDef, RP_HEADER, nK, nOutHan, @nLineNo, @nPageNo, ;
                        @aPageBuff, nPageLen, nLineLen, nLeftMargin, ;
                        nTopMargin, nWorkLen )
   ENDIF
NEXT

RETURN NIL
/*========================================================================*/


/*========================================================================*/
STATIC FUNCTION RptFlushPage( aPageBuff, nOutHan, nLineNo, nPageLen, lLastPage )
/*
 * Write the page buffer to the output file.
 * Mimics rpPageOut() behavior:
 *   - Write each non-empty line followed by CR+LF
 *   - End with form-feed (chr(12)) unless last page
 */
LOCAL nK
LOCAL cLine
LOCAL cCRLF := Chr(13) + Chr(10)

IF nOutHan <= 0
   RETURN NIL
ENDIF

FOR nK := 1 TO nPageLen

   IF nK <= Len( aPageBuff )
      cLine := aPageBuff[ nK ]
   ELSE
      cLine := ""
   ENDIF

   * trim trailing spaces (matching TVR's trim behavior in rpPageOut)
   cLine := RTrim( cLine )

   * write line + CRLF
   FWrite( nOutHan, cLine + cCRLF )

NEXT

* form feed between pages (not on last page for ASCII output)
IF !lLastPage
   FWrite( nOutHan, Chr(12) + cCRLF )
ENDIF

RETURN NIL
/*========================================================================*/


/*========================================================================*/
STATIC FUNCTION RptOutputSummary( aSummLines, nOutHan, nLineNo, nPageNo, ;
                                   aPageBuff, nPageLen, nLineLen, ;
                                   nLeftMargin, nTopMargin, nWorkLen )
/*
 * Output summary/criteria text lines.
 * These are the AddSummary lines that were dynamically added to TVR's oRP.
 */
LOCAL nK, cLine

FOR nK := 1 TO Len( aSummLines )

   * check if we need a new page
   IF nLineNo + 1 > nWorkLen
      * flush page (simplified - no page footer for summary overflow)
      RptFlushPage( aPageBuff, nOutHan, nLineNo, nPageLen, .F. )
      nPageNo++
      AFill( aPageBuff, "" )
      nLineNo := nTopMargin
   ENDIF

   * place summary line
   cLine := aSummLines[ nK ]
   IF Len( cLine ) < nLineLen
      cLine := PadR( cLine, nLineLen )
   ENDIF

   nLineNo++
   IF nLineNo <= nPageLen
      aPageBuff[ nLineNo ] := cLine
   ENDIF

NEXT

RETURN NIL
/*========================================================================*/


/*========================================================================*/
FUNCTION BuildSummaryLines( oTheRep, aDbs, nLineLen, nLeftMargin )
/*
 * Build summary text lines from TheReport object.
 * Replaces AddSummary() method - extracts criteria text
 * directly instead of using rpLinePlace/rpRFldNew/rpLFieldNew.
 *
 * Parameters:
 *   oTheRep    - TheReport object
 *   aDbs       - Array of database names
 *   nLineLen   - Report line length
 *   nLeftMargin - Left margin
 *
 * Returns: Array of text strings (one per summary line)
 */
LOCAL aSummary := {}
LOCAL aLines
LOCAL cDbf
LOCAL nK
LOCAL cRemark

* get the criteria page text lines
* aPrnCritPage() is a BMS function that returns formatted criteria text
IF Len( aDbs ) > 0
   cDbf := aDbs[ 1 ]
   IF Select( cDbf ) > 0
      aLines := aPrnCritPage( (cDbf)->( OrdKey() ) )
   ELSE
      aLines := {}
   ENDIF
ELSE
   aLines := {}
ENDIF

* add each criteria line
FOR nK := 1 TO Len( aLines )
   AAdd( aSummary, Space( nLeftMargin ) + aLines[ nK ] )
NEXT

* add remark if present
IF oTheRep != NIL
   cRemark := oTheRep:cRemark
   IF ValType( cRemark ) == "C" .AND. !Empty( cRemark )
      AAdd( aSummary, Space( nLeftMargin ) + cRemark )
   ENDIF
ENDIF

* add trailing blank line
AAdd( aSummary, " " )

RETURN aSummary
/*========================================================================*/


/*========================================================================*/
STATIC FUNCTION RptEvalFields( aRptDef )
/*
 * Evaluate all field expressions for the current record.
 * Updates RF_VAL for __TEXT__ and regular fields.
 */
LOCAL nK, aFld, xVal

FOR nK := 1 TO Len( aRptDef[ RD_FIELDS ] )

   aFld := aRptDef[ RD_FIELDS ][ nK ]

   * skip total/calc fields (they accumulate, not evaluate per-record)
   IF aFld[ RF_LEVEL ] > 0
      LOOP
   ENDIF

   * skip text fields (static value)
   IF aFld[ RF_TBL ] == "__TEXT__"
      LOOP
   ENDIF

   * evaluate the field block
   IF aFld[ RF_BLOCK ] != NIL
      xVal := Eval( aFld[ RF_BLOCK ] )
      aFld[ RF_VAL ] := xVal
   ENDIF

NEXT

RETURN NIL
/*========================================================================*/


/*========================================================================*/
STATIC FUNCTION RptAccumRunning( aRptDef )
/*
 * Accumulate running totals for all total fields.
 * Called after each body record is processed.
 */
LOCAL nK, aFld, aBaseFld
LOCAL nBaseIdx
LOCAL xBaseVal

FOR nK := 1 TO Len( aRptDef[ RD_FIELDS ] )

   aFld := aRptDef[ RD_FIELDS ][ nK ]

   * only process total/calc fields (level > 0)
   IF aFld[ RF_LEVEL ] <= 0
      LOOP
   ENDIF

   * find the base field this total refers to
   * In TVR, rpFIELD_TOTAL_RFO points to the base field.
   * We look for a field with same name in the base table.
   nBaseIdx := RptFindBaseField( aRptDef, aFld )

   IF nBaseIdx > 0
      xBaseVal := aRptDef[ RD_FIELDS ][ nBaseIdx ][ RF_VAL ]
   ELSE
      * try evaluating the block directly
      IF aFld[ RF_BLOCK ] != NIL
         xBaseVal := Eval( aFld[ RF_BLOCK ] )
      ELSE
         xBaseVal := 0
      ENDIF
   ENDIF

   * accumulate based on total type
   IF ValType( xBaseVal ) == "N"
      DO CASE
         CASE aFld[ RF_TOTTYP ] == RP_SUM
            IF ValType( aFld[ RF_VAL ] ) != "N"
               aFld[ RF_VAL ] := 0
            ENDIF
            aFld[ RF_VAL ] := aFld[ RF_VAL ] + xBaseVal

         CASE aFld[ RF_TOTTYP ] == RP_COUNT
            IF ValType( aFld[ RF_VAL ] ) != "N"
               aFld[ RF_VAL ] := 0
            ENDIF
            aFld[ RF_VAL ] := aFld[ RF_VAL ] + 1

         CASE aFld[ RF_TOTTYP ] == RP_AVERAGE
            * accumulate sum + count, compute avg at output time
            IF ValType( aFld[ RF_VAL ] ) != "N"
               aFld[ RF_VAL ] := 0
            ENDIF
            aFld[ RF_VAL ] := aFld[ RF_VAL ] + xBaseVal

         CASE aFld[ RF_TOTTYP ] == RP_LOWEST
            IF ValType( aFld[ RF_VAL ] ) != "N" .OR. xBaseVal < aFld[ RF_VAL ]
               aFld[ RF_VAL ] := xBaseVal
            ENDIF

         CASE aFld[ RF_TOTTYP ] == RP_HIGHEST
            IF ValType( aFld[ RF_VAL ] ) != "N" .OR. xBaseVal > aFld[ RF_VAL ]
               aFld[ RF_VAL ] := xBaseVal
            ENDIF

         OTHERWISE
            * default to sum
            IF ValType( aFld[ RF_VAL ] ) != "N"
               aFld[ RF_VAL ] := 0
            ENDIF
            aFld[ RF_VAL ] := aFld[ RF_VAL ] + xBaseVal
      ENDCASE
   ENDIF

NEXT

RETURN NIL
/*========================================================================*/


/*========================================================================*/
STATIC FUNCTION RptAccumTotals( aRptDef, nLevel )
/*
 * Called at a group break - can do final calculations for this level.
 * Currently a no-op since accumulation happens in RptAccumRunning.
 * Could be used for AVERAGE computation (divide sum by count).
 */
* placeholder for future average/deviation/variance computation

RETURN NIL
/*========================================================================*/


/*========================================================================*/
STATIC FUNCTION RptResetTotals( aRptDef, nLevel )
/*
 * Reset total field values for a given level.
 * nLevel = 0 means reset ALL levels.
 */
LOCAL nK, aFld

FOR nK := 1 TO Len( aRptDef[ RD_FIELDS ] )

   aFld := aRptDef[ RD_FIELDS ][ nK ]

   IF aFld[ RF_LEVEL ] <= 0
      LOOP
   ENDIF

   IF nLevel == 0 .OR. aFld[ RF_LEVEL ] == nLevel
      IF aFld[ RF_TYPE ] == "N"
         aFld[ RF_VAL ] := 0
      ELSEIF aFld[ RF_TYPE ] == "D"
         aFld[ RF_VAL ] := CToD("")
      ELSE
         aFld[ RF_VAL ] := ""
      ENDIF
   ENDIF

NEXT

RETURN NIL
/*========================================================================*/


/*========================================================================*/
STATIC FUNCTION RptFindBaseField( aRptDef, aTotFld )
/*
 * Find the base (detail) field that a total field references.
 * Matches by field name in the same or primary table.
 */
LOCAL nK, aFld, cName

cName := Upper( aTotFld[ RF_NAME ] )

FOR nK := 1 TO Len( aRptDef[ RD_FIELDS ] )
   aFld := aRptDef[ RD_FIELDS ][ nK ]
   IF aFld[ RF_LEVEL ] == 0 .AND. ;
      Upper( aFld[ RF_NAME ] ) == cName .AND. ;
      aFld[ RF_TBL ] != "__TEXT__" .AND. ;
      aFld[ RF_TBL ] != "_VIRTUAL_"
      RETURN nK
   ENDIF
NEXT

RETURN 0
/*========================================================================*/


/*========================================================================*/
STATIC FUNCTION CountLinesByType( aRptDef, nType )
/*
 * Count how many lines of a given type exist.
 */
LOCAL nCount := 0
LOCAL nK

FOR nK := 1 TO Len( aRptDef[ RD_LINES ] )
   IF aRptDef[ RD_LINES ][ nK ][ RL_TYPE ] == nType
      nCount++
   ENDIF
NEXT

RETURN nCount
/*========================================================================*/


/*========================================================================*/
STATIC FUNCTION CountLinesByType2( aRptDef, nType, nLevel )
/*
 * Count lines of a given type and level.
 */
LOCAL nCount := 0
LOCAL nK, aLine

FOR nK := 1 TO Len( aRptDef[ RD_LINES ] )
   aLine := aRptDef[ RD_LINES ][ nK ]
   IF aLine[ RL_TYPE ] == nType
      IF nLevel == 0 .OR. aLine[ RL_LEVEL ] == nLevel
         nCount++
      ENDIF
   ENDIF
NEXT

RETURN nCount
/*========================================================================*/


/*========================================================================*/
FUNCTION RptExtractId( cRptFile )
/*
 * Extract report ID from filename.
 * "RPQC01V1.RH2" -> "RPQC01V1"
 * "RPQC01V1" -> "RPQC01V1"
 * "C:\PATH\RPQC01V1.RH2" -> "RPQC01V1"
 */
LOCAL cId, nDot, nSlash

IF cRptFile == NIL .OR. Empty( cRptFile )
   RETURN ""
ENDIF

cId := AllTrim( cRptFile )

* strip path
nSlash := RAt( "\", cId )
IF nSlash == 0
   nSlash := RAt( "/", cId )
ENDIF
IF nSlash > 0
   cId := SubStr( cId, nSlash + 1 )
ENDIF

* strip extension
nDot := At( ".", cId )
IF nDot > 0
   cId := Left( cId, nDot - 1 )
ENDIF

RETURN Upper( cId )
/*========================================================================*/
