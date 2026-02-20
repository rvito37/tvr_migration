/*========================================================================
 * RH2TEST.PRG - Test harness for RH2 parser
 * Output written to RH2TEST.LOG
 *========================================================================*/

#include "fileio.ch"

REQUEST HB_GT_CGI_DEFAULT

FUNCTION Main()
LOCAL cFile, oRP, aFields, aLines, aDBs, aReport
LOCAL nK, oField, oLine, oDB
LOCAL cOutDir
LOCAL nLT, cLT, aS
LOCAL nLog
LOCAL bOldErr, oErr

* set error handler to avoid hanging on runtime errors
ErrorBlock( {|e| MyError(e) } )

* output to log file
nLog := FCREATE( "RH2TEST.LOG" )
IF nLog < 0
   QUIT
ENDIF

* test file
cFile := "C:\Users\AVXUser\BMS\RH2\RACC01V1.RH2"
cOutDir := "C:\Users\AVXUser\BMS\RPT_DBF\"

WriteLog( nLog, "=== RH2 Parser Test ===" )
WriteLog( nLog, "Parsing: " + cFile )
WriteLog( nLog, "" )

* parse the file
oRP := RH2_LoadReport( cFile )

IF oRP == NIL
   WriteLog( nLog, "ERROR: Failed to parse file!" )
   FCLOSE( nLog )
   QUIT
ENDIF

IF ValType( oRP ) != "A"
   WriteLog( nLog, "ERROR: Result is not an array! Type=" + ValType( oRP ) )
   FCLOSE( nLog )
   QUIT
ENDIF

WriteLog( nLog, "oRP array length: " + LTrim( Str( Len( oRP ) ) ) )
WriteLog( nLog, "" )

* show report settings
aReport := oRP[ 3 ]   // rpREPORT
IF ValType( aReport ) == "A"
   WriteLog( nLog, "--- REPORT SETTINGS ---" )
   WriteLog( nLog, "  Report array len: " + LTrim( Str( Len( aReport ) ) ) )
   IF Len( aReport ) >= 61
      WriteLog( nLog, "  Name:        [" + RH2_GetStr( aReport[ 43 ] ) + "]" )
      WriteLog( nLog, "  Page Length: " + LTrim( Str( RH2_GetNum( aReport[ 22 ] ) ) ) )
      WriteLog( nLog, "  Orientation: " + LTrim( Str( RH2_GetNum( aReport[ 39 ] ) ) ) )
      WriteLog( nLog, "  Margins T/L/B/R: " + ;
         LTrim(Str(RH2_GetNum(aReport[23]))) + "/" + ;
         LTrim(Str(RH2_GetNum(aReport[24]))) + "/" + ;
         LTrim(Str(RH2_GetNum(aReport[25]))) + "/" + ;
         LTrim(Str(RH2_GetNum(aReport[26]))) )
      WriteLog( nLog, "  Rec Width:   " + LTrim( Str( RH2_GetNum( aReport[ 61 ] ) ) ) )
   ENDIF
   WriteLog( nLog, "" )
ENDIF

* show fields
aFields := oRP[ 2 ]   // rpFIELDS
IF ValType( aFields ) == "A"
   WriteLog( nLog, "--- FIELDS (" + LTrim( Str( Len( aFields ) ) ) + ") ---" )
   FOR nK := 1 TO Min( Len( aFields ), 20 )
      oField := aFields[ nK ]
      IF ValType( oField ) == "A" .AND. Len( oField ) >= 8
         WriteLog( nLog, "  " + StrZero(nK,3) + ": " + ;
           Padr( RH2_GetStr( oField[1] ), 12 ) + ;
           Padr( RH2_GetStr( oField[2] ), 14 ) + ;
           RH2_GetStr( oField[3] ) + " " + ;
           Str( RH2_GetNum( oField[4] ), 4 ) + ;
           "  expr=" + Left( RH2_GetStr( oField[8] ), 40 ) )
      ENDIF
   NEXT
   IF Len( aFields ) > 20
      WriteLog( nLog, "  ... (" + LTrim( Str( Len(aFields) - 20 ) ) + " more)" )
   ENDIF
   WriteLog( nLog, "" )
ENDIF

* show databases
aDBs := oRP[ 4 ]   // rpDATABASE
IF ValType( aDBs ) == "A"
   WriteLog( nLog, "--- DATABASES (" + LTrim( Str( Len( aDBs ) ) ) + ") ---" )
   FOR nK := 1 TO Len( aDBs )
      oDB := aDBs[ nK ]
      IF ValType( oDB ) == "A" .AND. Len( oDB ) >= 3
         WriteLog( nLog, "  " + LTrim(Str(nK)) + ": " + ;
           Padr( RH2_GetStr( oDB[1] ), 20 ) + ;
           "  alias=" + RH2_GetStr( oDB[2] ) + ;
           "  idx=" + RH2_GetStr( oDB[3] ) )
      ENDIF
   NEXT
   WriteLog( nLog, "" )
ENDIF

* show lines
aLines := oRP[ 6 ]   // rpLINES
IF ValType( aLines ) == "A"
   WriteLog( nLog, "--- LINES (" + LTrim( Str( Len( aLines ) ) ) + ") ---" )
   FOR nK := 1 TO Len( aLines )
      oLine := aLines[ nK ]
      IF ValType( oLine ) == "A" .AND. Len( oLine ) >= 20
         nLT := RH2_GetNum( oLine[18] )   // LINE_TYPE
         cLT := ""
         DO CASE
            CASE nLT == 1; cLT := "TITLE"
            CASE nLT == 2; cLT := "PG_HDR"
            CASE nLT == 3; cLT := "HEADER"
            CASE nLT == 4; cLT := "BODY"
            CASE nLT == 5; cLT := "FOOTER"
            CASE nLT == 6; cLT := "SUMMARY"
            CASE nLT == 7; cLT := "PG_FTR"
            OTHERWISE;      cLT := "??(" + LTrim(Str(nLT)) + ")"
         ENDCASE
         aS := RH2_GetArr( oLine[1] )   // rpLFIELD_START
         WriteLog( nLog, "  L" + StrZero(nK,2) + ": " + ;
           Padr( cLT, 8 ) + ;
           " lvl=" + Str( RH2_GetNum( oLine[19] ), 2 ) + ;
           " row=" + Str( RH2_GetNum( oLine[20] ), 3 ) + ;
           " fields=" + LTrim( Str( Len( aS ) ) ) )
      ENDIF
   NEXT
   WriteLog( nLog, "" )
ENDIF

WriteLog( nLog, "=== Parse complete! ===" )
WriteLog( nLog, "" )
WriteLog( nLog, "Now converting ALL RH2 to DBF..." )

* run full batch conversion
ConvertAllRH2( ;
   "C:\Users\AVXUser\BMS\RH2", ;
   cOutDir, ;
   nLog )

WriteLog( nLog, "" )
WriteLog( nLog, "=== All done! ===" )

FCLOSE( nLog )
QUIT
RETURN NIL

/*========================================================================*/
STATIC FUNCTION WriteLog( nHan, cMsg )
FWRITE( nHan, cMsg + Chr(13) + Chr(10) )
RETURN NIL
/*========================================================================*/

/*========================================================================*/
FUNCTION MyError( oErr )
LOCAL nErrLog, cMsg
nErrLog := FCREATE( "RH2ERR.LOG" )
IF nErrLog >= 0
   cMsg := "RUNTIME ERROR!" + Chr(13)+Chr(10)
   cMsg := cMsg + "Description: " + oErr:Description + Chr(13)+Chr(10)
   cMsg := cMsg + "Operation: " + IIF( oErr:Operation != NIL, oErr:Operation, "?" ) + Chr(13)+Chr(10)
   cMsg := cMsg + "SubSystem: " + IIF( oErr:SubSystem != NIL, oErr:SubSystem, "?" ) + Chr(13)+Chr(10)
   cMsg := cMsg + "SubCode: " + LTrim(Str( oErr:SubCode )) + Chr(13)+Chr(10)
   cMsg := cMsg + "OsCode: " + LTrim(Str( oErr:OsCode )) + Chr(13)+Chr(10)
   cMsg := cMsg + "GenCode: " + LTrim(Str( oErr:GenCode )) + Chr(13)+Chr(10)
   cMsg := cMsg + "FileName: " + IIF( oErr:FileName != NIL, oErr:FileName, "?" ) + Chr(13)+Chr(10)
   FWRITE( nErrLog, cMsg )
   FCLOSE( nErrLog )
ENDIF
QUIT
RETURN .F.
/*========================================================================*/
