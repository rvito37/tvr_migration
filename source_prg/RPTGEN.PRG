/*========================================================================
 * RPTGEN.PRG - Native Clipper report generation engine
 *
 * Replaces rpGenReport() / rpGenerate() / rpMakeNew() / MAKEGROUP() / rpPageOut()
 * Reads report definition from DBF tables via LoadReportDef(),
 * iterates data records, formats output, writes to file.
 *
 * Produces text output IDENTICAL to what TVR produced.
 *
 * CRITICAL: The accumulation logic matches rpEval() from TVR exactly:
 *   - rpEval() both accumulates AND returns the display value
 *   - For SUM: TOTAL_VAL += base, VAL = TOTAL_VAL
 *   - For COUNT: COUNTER += IIF(empty,0,1), VAL = COUNTER
 *   - For AVERAGE: TOTAL_VAL += base, COUNTER += IIF(0,0,1), VAL = TOTAL_VAL/COUNTER
 *   - For LOWEST/HIGHEST: compare and keep min/max in TOTAL_VAL, VAL = TOTAL_VAL
 *   - rpLevelReset() resets VAL, TOTAL_VAL, AND COUNTER to 0
 *
 * Break processing matches rpBreakProcess() from GEN.PRG:
 *   - Skip BACK to previous record position for footer evaluation
 *   - rpUpdateAll(TRUE) at old position
 *   - rpUpdateLevel() for each break level
 *   - Output footers from HIGHEST level down to LOWEST
 *   - Skip FORWARD to current record
 *   - rpLevelReset() for each break level
 *   - Output headers from LOWEST level up to HIGHEST
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
#DEFINE RF_TOTVAL   14
#DEFINE RF_COUNTER  15

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
#DEFINE RP_DEVIATION     6
#DEFINE RP_VARIANCE      7

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
IF nDest == rpPRINTER_FILE .OR. nDest == rpPRINTER
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
 * PRECISELY matches rpGenerate() flow in GEN.PRG.
 *
 * TVR sequence per record:
 *   1. Check break levels (N -> 1)
 *   2. If break: rpBreakProcess()
 *      a. Skip back to previous record
 *      b. rpUpdateAll(TRUE) at old position
 *      c. rpUpdateLevel() for each break level
 *      d. Output footers (highest -> lowest)
 *      e. Skip forward to current record
 *      f. rpLevelReset() for each break level
 *      g. Output headers (lowest -> highest)
 *   3. rpUpdateAll() - evaluate all running/calc fields
 *   4. rpGenBody() - output body lines
 *   5. Save record position
 *   6. Skip to next record
 */
LOCAL nK, nY
LOCAL nBCntr
LOCAL nRecCount   := 0
LOCAL nBreakLevel := 0
LOCAL nLowBreak   := 0
LOCAL aLevels     := {}
LOCAL aLastVals   := {}
LOCAL aBreakList  := {}
LOCAL lHasLevels  := .F.
LOCAL cMasterAlias
LOCAL xCurrVal
LOCAL nLastRec     := 0
LOCAL nCurrRec     := 0

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
nBreakLevel := Len( aRptDef[ RD_LEVELS ] )
lHasLevels := nBreakLevel > 0
nBreakLevel := 0    // reset - it's used later for break detection

IF lHasLevels
   * build level break evaluation blocks from level field references
   aLevels   := Array( Len( aRptDef[ RD_LEVELS ] ) )
   aLastVals := Array( Len( aRptDef[ RD_LEVELS ] ) )
   FOR nK := 1 TO Len( aRptDef[ RD_LEVELS ] )
      nY := aRptDef[ RD_LEVELS ][ nK ][ RLV_FLD ]
      IF nY > 0 .AND. nY <= Len( aRptDef[ RD_FIELDS ] )
         aLevels[ nK ] := aRptDef[ RD_FIELDS ][ nY ][ RF_BLOCK ]
      ELSE
         aLevels[ nK ] := {|| "" }
      ENDIF
   NEXT
ENDIF

* initialize all totals
RptResetTotals( aRptDef, 0 )

* go to first record
DbGoTop()

* initial rpUpdateAll: evaluate all fields at first record
RptUpdateAll( aRptDef, .F. )

* save initial break level values
IF lHasLevels
   FOR nK := 1 TO Len( aRptDef[ RD_LEVELS ] )
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
   FOR nK := 1 TO Len( aRptDef[ RD_LEVELS ] )
      RptOutputSection( aRptDef, RP_HEADER, nK, nOutHan, @nLineNo, @nPageNo, ;
                        @aPageBuff, nPageLen, nLineLen, nLeftMargin, ;
                        nTopMargin, nWorkLen )
   NEXT
ENDIF

*
* ===== MAIN DATA LOOP =====
*
DO WHILE !Eof()

   nRecCount++

   * ------------------------------------------------------------------
   * STEP 1: Check for break levels (N -> 1, matching TVR exactly)
   * TVR checks from nBreakCnt down to 1 (step -1).
   * nBreakLevel = FIRST break detected (highest number)
   * nLowBreak   = LAST break detected (lowest number)
   * ------------------------------------------------------------------
   nBreakLevel := 0
   nLowBreak   := 0
   nBCntr      := 0

   IF lHasLevels
      FOR nK := Len( aRptDef[ RD_LEVELS ] ) TO 1 STEP -1
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
            nBCntr++
         ENDIF
      NEXT
   ENDIF

   * ------------------------------------------------------------------
   * STEP 2: Process break if detected
   * TVR's rpBreakProcess():
   *   - Builds aBreakList = {nBreakCnt, nBreakCnt-1, ..., nLowBreak}
   *     i.e. from highest level to lowest
   *   - Saves current position, goes BACK to previous record
   *   - rpUpdateAll(TRUE) at old position
   *   - rpUpdateLevel() for each level in aBreakList
   *   - rpGenFooters() for each level (highest -> lowest)
   *   - Goes FORWARD to current record
   *   - rpLevelReset() + update aLastVals for each level
   *   - rpGenHeaders() for levels (lowest -> highest)
   * ------------------------------------------------------------------
   IF nBreakLevel > 0

      * build break list: from highest (nBreakCnt) down to lowest (nLowBreak)
      * matching TVR: nBCntr := nBreakCnt - nLowBreak + 1
      nBCntr := Len( aRptDef[ RD_LEVELS ] ) - nLowBreak + 1
      aBreakList := Array( nBCntr )
      FOR nK := 1 TO nBCntr
         aBreakList[ nK ] := Len( aRptDef[ RD_LEVELS ] ) - nK + 1
      NEXT

      * SAVE current record position
      nCurrRec := RecNo()

      * GO BACK to previous record for footer evaluation
      IF nLastRec > 0
         DbGoto( nLastRec )
      ENDIF

      * rpUpdateAll(TRUE) at old record position
      * lCalcOnly=TRUE means only evaluate calc-on-total fields
      RptUpdateAll( aRptDef, .T. )

      * rpUpdateLevel() for each break level
      * This computes final total values for display in footers
      FOR nK := 1 TO nBCntr
         RptUpdateLevel( aRptDef, aBreakList[ nK ] )
      NEXT

      RptUpdateAll( aRptDef, .T. )

      * output footers from highest level to lowest
      * In TVR's multi-level break: footers go nBreakCnt down to nLowBreak
      FOR nK := 1 TO nBCntr
         RptOutputSection( aRptDef, RP_FOOTER, aBreakList[ nK ], ;
                           nOutHan, @nLineNo, @nPageNo, ;
                           @aPageBuff, nPageLen, nLineLen, nLeftMargin, ;
                           nTopMargin, nWorkLen )
      NEXT

      * GO FORWARD to current record
      DbGoto( nCurrRec )

      * check for page reset on break, update last vals, reset totals
      * Order matches TVR (line 2671): iterate aBreakList
      FOR nK := 1 TO nBCntr
         * check page reset flag
         IF aRptDef[ RD_LEVELS ][ aBreakList[ nK ] ][ RLV_PGRST ]
            RptNewPage( aRptDef, nOutHan, @nLineNo, @nPageNo, ;
                        @aPageBuff, nPageLen, nLineLen, nLeftMargin, ;
                        nTopMargin, nWorkLen )
         ENDIF

         * update saved break value
         IF aLevels[ aBreakList[ nK ] ] != NIL
            aLastVals[ aBreakList[ nK ] ] := Eval( aLevels[ aBreakList[ nK ] ] )
         ENDIF

         * reset totals for this level (VAL, TOTVAL, COUNTER)
         RptResetTotals( aRptDef, aBreakList[ nK ] )
      NEXT

      * rpUpdateAll at new record position
      RptUpdateAll( aRptDef, .T. )

      * output headers from lowest level to highest
      * TVR (line 2662): FOR nK := 1 to len(aBreakList) => highest to lowest
      * But the headers in standard break go low->high:
      * aBreakList = {3,2,1} so iterating 1..nBCntr gives 3,2,1 = high->low
      * Actually TVR (line 2662) iterates aBreakList 1..len which IS high->low
      * Let me re-check: aBreakList = {3,2,1}, FOR nK := 1 to 3 gives 3,2,1
      * That means headers go HIGHEST to LOWEST
      * Wait no - looking at original code line 2662:
      *   FOR nK := 1 to len( aBreakList )
      *     rpGenHeaders( oRP, aBreakList[ nK ], FALSE )
      *   NEXT
      * aBreakList[1]=nBreakCnt, aBreakList[2]=nBreakCnt-1, etc.
      * So headers go from HIGHEST level to LOWEST - same order as footers
      FOR nK := 1 TO nBCntr
         RptOutputSection( aRptDef, RP_HEADER, aBreakList[ nK ], ;
                           nOutHan, @nLineNo, @nPageNo, ;
                           @aPageBuff, nPageLen, nLineLen, nLeftMargin, ;
                           nTopMargin, nWorkLen )
      NEXT

   ENDIF

   * ------------------------------------------------------------------
   * STEP 3: rpUpdateAll() - evaluate all running/calc fields
   * This calls rpEval() which BOTH accumulates totals AND evaluates
   * detail fields for the current record.
   * ------------------------------------------------------------------
   RptUpdateAll( aRptDef, .F. )

   * ------------------------------------------------------------------
   * STEP 4: Check if body lines will fit, then output body
   * ------------------------------------------------------------------
   IF nLineNo + CountLinesByType2( aRptDef, RP_BODY, 0 ) > nWorkLen
      RptNewPage( aRptDef, nOutHan, @nLineNo, @nPageNo, ;
                  @aPageBuff, nPageLen, nLineLen, nLeftMargin, ;
                  nTopMargin, nWorkLen )
   ENDIF

   RptOutputSection( aRptDef, RP_BODY, 0, nOutHan, @nLineNo, @nPageNo, ;
                     @aPageBuff, nPageLen, nLineLen, nLeftMargin, ;
                     nTopMargin, nWorkLen )

   * ------------------------------------------------------------------
   * STEP 5: Save current record position (for footer skip-back)
   * ------------------------------------------------------------------
   nLastRec := RecNo()

   * ------------------------------------------------------------------
   * STEP 6: Skip to next record
   * ------------------------------------------------------------------
   DbSkip()

ENDDO

* ===== END OF DATA =====

* Go back to last record for final footers (matching TVR line 913)
IF nLastRec > 0
   DbGoto( nLastRec )
ENDIF

* rpUpdateAll(TRUE) at last position
RptUpdateAll( aRptDef, .T. )

* do final footers (all levels, highest to lowest)
* TVR (line 955): FOR nK := nBreakCnt to 1 step -1
IF lHasLevels
   FOR nK := Len( aRptDef[ RD_LEVELS ] ) TO 1 STEP -1
      RptUpdateLevel( aRptDef, nK )
      RptUpdateAll( aRptDef, .T. )
      RptOutputSection( aRptDef, RP_FOOTER, nK, nOutHan, @nLineNo, @nPageNo, ;
                        @aPageBuff, nPageLen, nLineLen, nLeftMargin, ;
                        nTopMargin, nWorkLen )
   NEXT
ENDIF

* output summary section (criteria text)
IF Len( aSummLines ) > 0
   * TVR line 974: rpGenSummary()
   RptOutputSummary( aSummLines, nOutHan, @nLineNo, @nPageNo, ;
                     @aPageBuff, nPageLen, nLineLen, nLeftMargin, ;
                     nTopMargin, nWorkLen )
ENDIF

* output page footers for last page
RptOutputSection( aRptDef, RP_PAGE_FOOTER, 0, nOutHan, @nLineNo, @nPageNo, ;
                  @aPageBuff, nPageLen, nLineLen, nLeftMargin, ;
                  nTopMargin, nWorkLen )

* flush last page (lLastPage=TRUE means no form-feed after)
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

         * get value (always use RF_VAL - already computed by RptUpdateAll/RptUpdateLevel)
         * TVR's rpMakeNew() reads from rpFIELD_VAL directly
         IF aFld[ RF_TBL ] == "__TEXT__"
            * text field: value is the long name (static)
            xVal := aFld[ RF_LONG ]
         ELSE
            * all other fields (detail and total): use pre-computed value
            xVal := aFld[ RF_VAL ]
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

* flush current page to output (NOT last page, so include form-feed)
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
 * Matches rpPageOut() behavior for FILE output:
 *   - Write each line followed by CR+LF
 *   - Trim trailing spaces
 *   - Form-feed (chr(12)) between pages BUT NOT after last page
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

* form feed between pages (NOT on last page)
* TVR's rpPageOut does NOT add form-feed itself; it comes from
* the page content. For file output, we add chr(12) between pages.
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
 */
LOCAL nK, cLine

FOR nK := 1 TO Len( aSummLines )

   * check if we need a new page
   IF nLineNo + 1 > nWorkLen
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
 * Replaces AddSummary() method.
 */
LOCAL aSummary := {}
LOCAL aLines
LOCAL cDbf
LOCAL nK
LOCAL cRemark

* get the criteria page text lines
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
STATIC FUNCTION RptUpdateAll( aRptDef, lCalcOnly )
/*
 * Evaluate all fields for the current record.
 * MATCHES rpUpdateAll() in GEN.PRG exactly.
 *
 * TVR's rpUpdateAll logic (line 3164-3190):
 *   IF lCalcOnly AND nFLevel==0 AND nFFreq==0: rpEval
 *   ELSEIF !lCalcOnly AND (nFLevel==0 OR nFFreq==0): rpEval
 *
 * Where:
 *   nFLevel = field level (0=detail, >0=total)
 *   nFFreq  = accumulation frequency (0=running, >0=level-specific)
 *   rpEval  = evaluates block for detail, accumulates for total
 *
 * lCalcOnly = TRUE:
 *   Only re-evaluates detail fields (level=0) with freq=0
 *   to refresh their values. Does NOT touch total fields.
 *   Used at break time to update calculated detail fields
 *   before computing totals.
 *
 * lCalcOnly = FALSE:
 *   Evaluates detail fields AND accumulates running totals (freq=0).
 *   Used per-record in the main loop.
 */
LOCAL nK, aFld
LOCAL nFLevel, nFFreq

IF lCalcOnly == NIL
   lCalcOnly := .F.
ENDIF

FOR nK := 1 TO Len( aRptDef[ RD_FIELDS ] )

   aFld := aRptDef[ RD_FIELDS ][ nK ]

   * skip text fields
   IF aFld[ RF_TBL ] == "__TEXT__"
      LOOP
   ENDIF

   nFLevel := aFld[ RF_LEVEL ]
   nFFreq  := aFld[ RF_TOTACC ]

   IF lCalcOnly
      * calc-only: evaluate detail fields (level=0, freq=0)
      IF nFLevel == 0 .AND. nFFreq == 0
         RptEvalField( aFld )
      ENDIF
   ELSE
      * normal: evaluate if level=0 OR freq=0
      IF nFLevel == 0 .OR. nFFreq == 0
         RptEvalField( aFld )
      ENDIF
   ENDIF

NEXT

RETURN NIL
/*========================================================================*/


/*========================================================================*/
STATIC FUNCTION RptUpdateLevel( aRptDef, nLevel )
/*
 * Compute final total values for fields at a specific level.
 * MATCHES rpUpdateLevel() in GEN.PRG (line 3097-3144).
 *
 * Called at break time to compute the value that will be displayed
 * in footer lines.
 *
 * TVR logic (line 3130):
 *   IF nFFreq == nLevel OR
 *      (nLevel == nFLevel AND nFLevel != 0 AND
 *       (nFFreq == RP_GRANDTOTAL OR nFFreq == RP_PAGEBREAK))
 *     => evaluate the field
 *
 * In our simplified model:
 *   IF field's level matches nLevel => call RptEvalField to compute
 */
LOCAL nK, aFld

FOR nK := 1 TO Len( aRptDef[ RD_FIELDS ] )

   aFld := aRptDef[ RD_FIELDS ][ nK ]

   * skip non-total fields
   IF aFld[ RF_LEVEL ] <= 0
      LOOP
   ENDIF

   * skip text fields
   IF aFld[ RF_TBL ] == "__TEXT__"
      LOOP
   ENDIF

   * check if this field matches the requested level
   * Match by TOTACC (accumulation frequency) or LEVEL
   IF aFld[ RF_TOTACC ] == nLevel .OR. ;
      ( aFld[ RF_LEVEL ] == nLevel .AND. aFld[ RF_LEVEL ] != 0 )
      * evaluate/accumulate this field
      RptEvalField( aFld )
   ENDIF

NEXT

RETURN NIL
/*========================================================================*/


/*========================================================================*/
STATIC FUNCTION RptEvalField( aFld )
/*
 * Evaluate a single field - handles both detail and total field types.
 * MATCHES rpEval() from TVR's RPEVAL.PRG exactly.
 *
 * For detail fields (level=0): just evaluate the block
 * For total fields (level>0): accumulate AND compute display value
 *
 * This is the CORE of the totaling engine.
 */
LOCAL xTmp

* detail field - just evaluate
IF aFld[ RF_LEVEL ] == 0
   IF aFld[ RF_BLOCK ] != NIL
      aFld[ RF_VAL ] := Eval( aFld[ RF_BLOCK ] )
   ENDIF
   RETURN aFld[ RF_VAL ]
ENDIF

* total field - accumulate based on type
DO CASE

   CASE aFld[ RF_TOTTYP ] == RP_COUNT
      * COUNT: count non-empty values
      IF aFld[ RF_BLOCK ] != NIL
         xTmp := Eval( aFld[ RF_BLOCK ] )
      ELSE
         xTmp := ""
      ENDIF
      aFld[ RF_COUNTER ] := aFld[ RF_COUNTER ] + ;
                             IIF( Empty( xTmp ), 0, 1 )
      aFld[ RF_VAL ] := aFld[ RF_COUNTER ]

   CASE aFld[ RF_TOTTYP ] == RP_SUM
      * SUM: add to running total
      IF aFld[ RF_BLOCK ] != NIL
         xTmp := Eval( aFld[ RF_BLOCK ] )
      ELSE
         xTmp := 0
      ENDIF
      IF ValType( xTmp ) == "N"
         aFld[ RF_TOTVAL ] := aFld[ RF_TOTVAL ] + xTmp
      ENDIF
      aFld[ RF_VAL ] := aFld[ RF_TOTVAL ]

   CASE aFld[ RF_TOTTYP ] == RP_AVERAGE
      * AVERAGE: accumulate sum + count, compute avg
      IF aFld[ RF_BLOCK ] != NIL
         xTmp := Eval( aFld[ RF_BLOCK ] )
      ELSE
         xTmp := 0
      ENDIF
      IF ValType( xTmp ) == "N"
         aFld[ RF_TOTVAL ] := aFld[ RF_TOTVAL ] + xTmp
         aFld[ RF_COUNTER ] := aFld[ RF_COUNTER ] + ;
                                IIF( xTmp == 0, 0, 1 )
      ENDIF
      IF aFld[ RF_COUNTER ] == 0
         aFld[ RF_VAL ] := 0
      ELSE
         aFld[ RF_VAL ] := aFld[ RF_TOTVAL ] / aFld[ RF_COUNTER ]
      ENDIF

   CASE aFld[ RF_TOTTYP ] == RP_LOWEST
      * LOWEST: keep minimum
      IF aFld[ RF_BLOCK ] != NIL
         xTmp := Eval( aFld[ RF_BLOCK ] )
      ELSE
         xTmp := 0
      ENDIF
      IF ( Empty( aFld[ RF_TOTVAL ] ) ) .OR. ;
         ( ValType( aFld[ RF_TOTVAL ] ) == "N" .AND. xTmp < aFld[ RF_TOTVAL ] )
         aFld[ RF_TOTVAL ] := xTmp
      ENDIF
      aFld[ RF_VAL ] := aFld[ RF_TOTVAL ]

   CASE aFld[ RF_TOTTYP ] == RP_HIGHEST
      * HIGHEST: keep maximum
      IF aFld[ RF_BLOCK ] != NIL
         xTmp := Eval( aFld[ RF_BLOCK ] )
      ELSE
         xTmp := 0
      ENDIF
      IF ( ValType( aFld[ RF_TOTVAL ] ) == "N" .AND. xTmp > aFld[ RF_TOTVAL ] ) .OR. ;
         ( Empty( aFld[ RF_TOTVAL ] ) )
         aFld[ RF_TOTVAL ] := xTmp
      ENDIF
      aFld[ RF_VAL ] := aFld[ RF_TOTVAL ]

   CASE aFld[ RF_TOTTYP ] == RP_DEVIATION
      * STANDARD DEVIATION
      IF aFld[ RF_BLOCK ] != NIL
         xTmp := Eval( aFld[ RF_BLOCK ] )
      ELSE
         xTmp := 0
      ENDIF
      IF ValType( xTmp ) == "N"
         aFld[ RF_TOTVAL ] := aFld[ RF_TOTVAL ] + xTmp
         aFld[ RF_COUNTER ] := aFld[ RF_COUNTER ] + ;
                                IIF( xTmp == 0, 0, 1 )
      ENDIF
      IF aFld[ RF_COUNTER ] == 0
         aFld[ RF_VAL ] := 0
      ELSE
         xTmp := ( aFld[ RF_TOTVAL ] ^ 2 ) / aFld[ RF_COUNTER ]
         xTmp := xTmp - ( aFld[ RF_TOTVAL ] / aFld[ RF_COUNTER ] ) ^ 2
         aFld[ RF_VAL ] := Sqrt( xTmp )
      ENDIF

   CASE aFld[ RF_TOTTYP ] == RP_VARIANCE
      * VARIANCE
      IF aFld[ RF_BLOCK ] != NIL
         xTmp := Eval( aFld[ RF_BLOCK ] )
      ELSE
         xTmp := 0
      ENDIF
      IF ValType( xTmp ) == "N"
         aFld[ RF_TOTVAL ] := aFld[ RF_TOTVAL ] + xTmp
         aFld[ RF_COUNTER ] := aFld[ RF_COUNTER ] + ;
                                IIF( xTmp == 0, 0, 1 )
      ENDIF
      IF aFld[ RF_COUNTER ] == 0
         aFld[ RF_VAL ] := 0
      ELSE
         xTmp := ( aFld[ RF_TOTVAL ] ^ 2 ) / aFld[ RF_COUNTER ]
         xTmp := xTmp - ( aFld[ RF_TOTVAL ] / aFld[ RF_COUNTER ] ) ^ 2
         aFld[ RF_VAL ] := xTmp
      ENDIF

   OTHERWISE
      * unknown total type - default to SUM behavior
      IF aFld[ RF_BLOCK ] != NIL
         xTmp := Eval( aFld[ RF_BLOCK ] )
      ELSE
         xTmp := 0
      ENDIF
      IF ValType( xTmp ) == "N"
         aFld[ RF_TOTVAL ] := aFld[ RF_TOTVAL ] + xTmp
      ENDIF
      aFld[ RF_VAL ] := aFld[ RF_TOTVAL ]

ENDCASE

RETURN aFld[ RF_VAL ]
/*========================================================================*/


/*========================================================================*/
STATIC FUNCTION RptResetTotals( aRptDef, nLevel )
/*
 * Reset total field values for a given level.
 * MATCHES rpLevelReset() in GEN.PRG (line 3195-3249).
 *
 * Resets: RF_VAL, RF_TOTVAL, AND RF_COUNTER
 * nLevel = 0 means reset ALL total fields.
 *
 * TVR logic (line 3220):
 *   IF (nLevel==0 AND nFLevel!=0) OR
 *      (nLevel>0 AND nFLevel==nLevel) OR
 *      (nLevel==nFLevel)
 */
LOCAL nK, aFld

FOR nK := 1 TO Len( aRptDef[ RD_FIELDS ] )

   aFld := aRptDef[ RD_FIELDS ][ nK ]

   IF aFld[ RF_LEVEL ] <= 0
      LOOP
   ENDIF

   IF ( nLevel == 0 .AND. aFld[ RF_LEVEL ] != 0 ) .OR. ;
      ( nLevel > 0 .AND. aFld[ RF_LEVEL ] == nLevel ) .OR. ;
      ( nLevel == aFld[ RF_LEVEL ] )

      * reset ALL three accumulators (matching rpLevelReset exactly)
      DO CASE
         CASE aFld[ RF_TYPE ] == "N"
            aFld[ RF_VAL ]     := 0
            aFld[ RF_TOTVAL ]  := 0
            aFld[ RF_COUNTER ] := 0
         CASE aFld[ RF_TYPE ] == "C"
            aFld[ RF_VAL ]     := ""
            aFld[ RF_TOTVAL ]  := ""
            aFld[ RF_COUNTER ] := 0
         CASE aFld[ RF_TYPE ] == "D"
            aFld[ RF_VAL ]     := CToD("")
            aFld[ RF_TOTVAL ]  := CToD("")
            aFld[ RF_COUNTER ] := 0
         OTHERWISE
            aFld[ RF_VAL ]     := .F.
            aFld[ RF_TOTVAL ]  := .F.
            aFld[ RF_COUNTER ] := 0
      ENDCASE
   ENDIF

NEXT

RETURN NIL
/*========================================================================*/


/*========================================================================*/
STATIC FUNCTION CountLinesByType( aRptDef, nType )
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
