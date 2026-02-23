/*========================================================================
 * THEREPO_NEW.PRG - Modified TheReport class
 *
 * This file contains ONLY the modified Print() and AddSummary() methods.
 * All other methods remain UNCHANGED from the original THEREPO.PRG.
 *
 * INSTRUCTIONS FOR INTEGRATION:
 * 1. In the original THEREPO.PRG, replace the Print() method
 *    (lines ~481-636) with the Print() method below.
 * 2. Replace the AddSummary() method (lines ~1044-1071) with the
 *    AddSummary() method below.
 * 3. Remove the TVR #include lines and add our constants.
 * 4. Keep ALL other methods exactly as-is.
 *
 * Changes from original:
 * - Print() no longer calls ANY TVR functions (rpNew, rpQuickLoad,
 *   rpGenReport, rpPageOut, rpGetRDO, rpMyDBOpen, rpDBTable, etc.)
 * - Instead calls GenReportFromDBF() from RPTGEN.PRG
 * - AddSummary() no longer uses rpLinePlace/rpRFldNew/rpLFieldNew
 *   Summary is built directly as text lines by GenReportFromDBF
 * - The lCreateORP / cbBuildRep dynamic report path is preserved
 *   but uses our engine instead of TVR
 *
 * Target: Clipper 5.3
 *========================================================================*/


/*========================================================================
 * HEADER CHANGES:
 *
 * REMOVE these lines from the top of THEREPO.PRG:
 *   (none - THEREPO.PRG doesn't #include rp.ch or rptrans.ch)
 *
 * The existing #DEFINE constants at the top of THEREPO.PRG can stay
 * since they are just numeric constants (rpPRINTER=1, rpPRINTER_FILE=2, etc.)
 * But we don't need:
 *   #DEFINE rpREPORT                  3
 *   #DEFINE rpREPORT_SHOW_COUNTER     78
 *   #DEFINE rpDATABASE                4
 *   #DEFINE rpDATABASE_ALIAS          2
 *   #DEFINE rpLINES                   6
 * These were used to index into oRP array. We no longer use oRP.
 * However, they don't hurt if left in place.
 *
 * ADD this line (or set via config/environment):
 *   STATIC cRptDBFDir := "RPT_DBF\"
 * This is the directory where the 8 RPT_*.DBF files are located.
 * Adjust path as needed for the production environment.
 *========================================================================*/


/*========================================================================
 * NEW Print() Method - replaces lines 481-636 of THEREPO.PRG
 *========================================================================*/
********************************
Method PRINT( l2ndLoop, cNtxExp, lPrintSummary, lSeeMessage )
********************************
*
* This method creates the temp file and generates the report output.
* MODIFIED: Uses GenReportFromDBF() instead of TVR functions.
*
LOCAL cOrigScreen := SaveVideo()
LOCAL cIndExpr
LOCAL cDriver
LOCAL cDBFDir

PRIVATE aTestBlocks, aBuffer

aTestBlocks := ::aTstBlocks
aBuffer     := ::aMyBuffer

DEFAULT lPrintSummary TO FALSE
DEFAULT l2ndLoop TO FALSE
DEFAULT cNtxExp  TO ""

@ 2,0 SAY PadR( "Loading report..." , 80 ) COLOR "W+/R"

*
* Create the filtered/indexed temp DBF (same as before)
*
IF ::lPrepDbf
   cIndExpr := SELF:CreateCondDb( , lSeeMessage )
ENDIF

*
* Open all databases needed for the report
*
GenOpenFiles( ::aDBs )

*
* Set relations if configured
*
IF ValType( ::cbSetRelation ) == "B"
   Eval( ::cbSetRelation, Self )
ENDIF

*
* Make sure we're on the primary database
*
IF Select( ::aDbs[1] ) > 0
   SELECT( Select( ::aDbs[1] ) )
ENDIF

@ 2,0 SAY PadR( "Generating report..." , 80 ) COLOR "W+/R"

*
* Determine RPT_DBF directory
* This is where the 8 RPT_*.DBF tables are stored
*
cDBFDir := RptDBFPath()

*
* Generate the report using our native engine
* GenReportFromDBF() handles everything:
*   - Loading report definition from DBF tables
*   - Iterating through data records
*   - Evaluating field expressions
*   - Formatting values
*   - Building output lines
*   - Writing to output file
*   - Summary/criteria text (replaces AddSummary)
*
GenReportFromDBF( ::cRepFileName, ::cTempFileDir, ::nDest, ::aDbs, ;
                  ::aTstBlocks, ::aMyBuffer, Self, cDBFDir )

*
* Post-generation cleanup
*
IF ::nDest == rpPRINTER_FILE
   fn_fLPTCap()
ELSEIF ::nDest == rpPRINTER
   IF ::nOldPrinter != NIL .AND. ;
      ::nOldPrinter != GetUserInfo():nActivePrinter
      SetNewPrinter( ::nOldPrinter )
   ENDIF
ENDIF

*
* Close report databases (simplified cleanup)
*
genCloseFiles( ::aDBS )

RestVideo( cOrigScreen )
KEYBOARD CHR(0)
INKEY()
RETURN( NIL )


/*========================================================================
 * NEW AddSummary() Method - replaces lines 1044-1071 of THEREPO.PRG
 *
 * In the new architecture, summary lines are built directly by
 * GenReportFromDBF() via BuildSummaryLines(). This method is kept
 * as a no-op for backward compatibility in case external code calls it.
 *========================================================================*/
**********************
Method AddSummary( oRP )
**********************
* No-op in new architecture.
* Summary/criteria text is now generated directly by GenReportFromDBF()
* via the BuildSummaryLines() function in RPTGEN.PRG.
*
* If oRP is passed (old TVR code path), we ignore it.
* The summary lines are built from:
*   - aPrnCritPage() for criteria text
*   - ::cRemark for additional remarks
*
RETURN Self


/*========================================================================
 * RptDBFPath() - Returns the path to RPT_*.DBF files
 *
 * This is a new function that returns the directory where the
 * report definition DBF tables are stored.
 * Modify this for your environment.
 *========================================================================*/
FUNCTION RptDBFPath()
LOCAL cPath

* Try environment variable first
* cPath := GetEnv( "RPT_DBF_DIR" )
* IF !Empty( cPath )
*    RETURN cPath
* ENDIF

* Default: RPT_DBF subdirectory relative to executable
* Adjust this path for your production environment!
cPath := "RPT_DBF\"

RETURN cPath
/*========================================================================*/
