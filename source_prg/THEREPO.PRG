#include "avxdefs.ch"
#DEFINE rpREPORT                  3
#DEFINE rpREPORT_SHOW_COUNTER     78
#DEFINE rpDATABASE                4
#DEFINE rpDATABASE_ALIAS          2
#DEFINE rpLINES                   6
#DEFINE rpPRINTER                 1
#DEFINE rpPRINTER_FILE            2
#DEFINE rpDISPLAY                 3
#DEFINE rpHTML                    4
#DEFINE RP_SUMMARY                6

STATIC cRepName
STATIC oMyRep
CREATE CLASS TheReport

EXPORTED:
       VAR aGetBuffer     // List of the
       VAR aCheckBlocks   // The code block for chrck screen
       VAR aCritList      //  List of Criteryonim
       VAR aCut           //  Not used
       VAR aDBs           // Array of db's participate in report (Main dbf always first)
                          // the rest are usualy lookups
       VAR aFldList       // For Spread Sheet
       VAR aKeyList       // Key list for query
       VAR aMyBuffer      // The result of user selection
       VAR aOrp
       VAR aSortList      //  Sort List with index expression
       VAR aSortName      //  Sort List with index Name
       VAR aSortExpr      //  Sort List  index expression
		 VAR aShortShow     // option for short represent
       VAR aTheMenu       // Array of options.
       VAR aTstBlocks     // Code block to check query against DB
       VAR aTitles        // For Spread Sheet
       VAR aXTabCargo     // to handle any special info for crosstab reports
       VAR aSuperCriteria // YG 11/10/97 list of which criteria will have indexes sent for them if chosen, in order of priority
       VAR aSuperIndexes  // YG 11/10/97 list of indexes for the above criteria
       VAR aHandyArray    // YG just in case you have some goodies you want sent below deck
       var aReports       // �"�� ����� ����� �������Tvr � ���� �� ����� ����
                          // YG 1/3/98 an optional array of several different tvr
                          // reports for the report. The array wull have the
                          // same number of members as there are sort options.
       VAR cBaseIndex
       VAR cBottom
       VAR cDevType       // Device type in string
       VAR cPrepDbf       // the name of the DB that being create
       VAR cPrepShort     // YH 7-8-00 ����� ���� ���� ��� instance
       VAR cRemark        // Add Remark to the end of the report
       VAR cRepBotTitle   // Report bottom-title
       VAR cRepDbf        // The name that I used in the report design
       VAR cRepFileName   // TVR file name
       VAR cReportName    // Report name by spec
       VAR cRepTitle      // Report sub-title
       VAR cSortType      // Hold the selected sort type
       VAR cSubTitle
       VAR aSubtiltle
       VAR cTempFileDir   // Temporory Directory
       VAR cTop
       VAR cTypeOfReport  // Report Query

       VAR cbBuildRep     // Build Report on TheFly  //YG don't use rh2 but direct hard code report, and remember, always zip up it first
       VAR cbExtraCond    // Extra Hard Coded condition not selecteble
       VAR cbPrepDbf      // Code Block That preper the filtered DB
       VAR cbPrepShort    // YH 7-8-00 ������ ����� ����� ���� ���
       VAR cbPreQuery     // the name of the DB that being create for query. uhg uhg
       VAR cbSetRelation  // To set Relations for all kind of things.

       VAR lBuildDBF      // Build Report on TheFly
       VAR lCreateOrp     // If true create ORP  from defenition he have.
       VAR lCustFile
       VAR lDoIndex
       VAR lMultiIndex
       VAR lPrepDbf       // Logical Should I build filtered DB
       VAR lRelIndex
       VAR lUseScope       // YG instead of using the temporary file use the scope in the index
       VAR lWeWantDiffMenu    // For Pre Menu
       VAR lSuperSmart    // For mutiple indexes YG 11/10/97
       VAR nDest          // Destination in numeric for TVR

       VAR nOldPrinter
       VAR nSmartCriteria
       VAR nScopeOn

       VAR oScrl          // to hold scroll windows

       VAR QApplyKeys     // Code block with applay key to query brow
                          //{|nKey , o , oForm | ApplyKeys(nKey,o,oForm ) }
       VAR Freeze
       VAR SmartSelect
       VAR SmartIndex
       VAR lDest          // Logical if to display the destination section

       METHOD init
       METHOD EXEC
       METHOD Print
       METHOD SpreadSheet
       METHOD V7Export
       METHOD SetTitles
       METHOD SetSubTitles
       METHOD SetFields
       METHOD SetQueryBlocks
       METHOD SetBuffer
       METHOD SetCheck
       METHOD SetCrit
       METHOD SetDB
       METHOD SetSort
       METHOD SetExprSort
       Method GetDestin
       Method SetDest
       METHOD CreateCondDb
       METHOD IndexTempFile
       Method AddSummary
       METHOD Query
       METHOD GetTheScopt

END CLASS

/**************************************************************************/
**************************************
METHOD init(ReportName,RepTitle,cType)
**************************************
DEFAULT cTYPE TO "REPORT"
       ::cReportName      := ReportName
       cRepName           := ReportName
       oMyRep             := self
       ::cRepTitle        := RepTitle
       ::aSortList        := {}
       ::aSortExpr        := {}
       ::aSortName        := {}
       ::aCritList        := {}
		 ::aShortShow       := {}
       ::aCheckBlocks     := {}
       ::aGetBuffer       := {}
       ::aTstBlocks       := {}
       ::aMyBuffer        := {}
       ::aSubtiltle       := {}
       ::aSuperCriteria   := {}    // YG 11/10/97 list of which criteria will have indexes sent for them if chosen
       ::aSuperIndexes    := {}    // YG 11/10/97 list of indexes for the above criteria
       ::aHandyArray      := {}    // YG 23/11/97 thought it might come in handy
       ::aReports         := {}    // YG 1/3/98
       *
       * ������� ����� ����� ����� ������ ����� �����
       *
       ::cTempFileDir     := GetTempFileDir()
       ::cTypeOfReport    := cType
       ::lWeWantDiffMenu  := FALSE
       ::lUseScope        := FALSE
       ::lDoIndex         := TRUE
       ::Freeze           := 0
       ::lRelIndex        := FALSE
       ::lPrepDbf         := TRUE
       ::lBuildDbf        := FALSE
       ::lCreateOrp       := FALSE
       ::aXTabCargo       := {"",{},"",{},{}}
       ::lCustFile        := FALSE
       ::SmartSelect      := FALSE
       ::lSupersmart      := FALSE
       ::lMultiIndex      := FALSE
       ::lDest            := TRUE    // te default to all reports
//       ::cRepBotTitle     := ""
RETURN SELF

METHOD SetSort(aSort)
   ::aSortList := aSort
RETURN Self

METHOD SetExprSort(aSort)
   ::aSortExpr := aSort
RETURN Self

METHOD SetDB(aDb)
   ::aDBs := aDB
RETURN Self

METHOD SetCrit(aCrit)
   ::aCritList := aCrit
RETURN Self
*
*  oRep:aCheckBlocks ���� instance � ����������� ������-���� ����
*
METHOD SetCheck(aCheck)
   ::aCheckBlocks := aCheck
RETURN Self

METHOD SetBuffer(aBuff)
   ::aGetBuffer := aBuff
RETURN Self
*
*  .T. ������ ������ ���� oRep �� instance � ���� SetQueryBlocks ���� METHOD �
*   .Rpqc##V1.prg �"� ���� �� ���� .�� �� .F. � ������ ��������� ���� ����� ��
*
METHOD SetQueryBlocks(aTest)
   ::aTstBlocks := aTest
RETURN Self

METHOD SetFields(aField)
   ::aFldList := aField
RETURN Self

METHOD SetTitles(aTit)
   ::aTitles := aTit
RETURN Self

METHOD SetSubTitles(aTit)
   ::aSubtiltle := aTit
RETURN Self

METHOD SetDest(lMyDest)
   ::lDest := lMyDest
RETURN Self



METHOD SetShort(aShortShow)
   ::aShortShow := aShortShow
RETURN Self


*************
METHOD EXEC(lSeeMessage)//vitaly for sched 19.09.2000
*************
LOCAL i,nKey,cIndExpr,cDriver,xKey
scrnPush()
SetColor("w+/b")
CLS
*
* PrnFace � aCheckBlocks ��� ���� ����� (oRep:aCheckBlocks) ����������� ������� ���� ����
*
SetCheckBlocks( ::aCheckBlocks ) //sets mysterious variable "aCheckBlocks" to ::aCheckBlocks in prnface any change to aCheckBlocks in prnface gets updated in ::aCheckblocks

//YG the following chunk of code handles keyboard input and user choices
//YG actuall execuation takes place at the end of the method ::print() etc.

IF ::lWeWantDiffMenu
    nKey :=  PopMenu(::aTheMenu,12,25)
ENDIF
DO CASE
   CASE nKey == NIL .or. nKey == 2

        IF ::cTypeOfReport == "REPORT"
           SetTheDevices(2)  //sets variable "ndevices" to 2 in prnface
        ELSEIF ::cTypeOfReport <> "V7EXPORT"
           SetTheDevices(3)
        ELSEIF ::cTypeOfReport == "V7EXPORT"
           SetTheDevices(4)
        ENDIF
        *
        * ���������� ������ ���� �"� ����������� ����,����������� ������� ����� ����
        *
        prnFace( ::aSortList , ::aCritList ,{::cReportName,::cRepTitle } , 1, ::cSubTitle ,::aSuperCriteria,::lDest) //YG - This seems to paint the criteria input opening screen ::lPrepDbf := TRUE
   CASE nKey == 1
        IF CustomPline(::cPrepDbf,Self,::aDbs[1],::cBaseIndex) //YG This is some weird function asking if you want to customize the pline whatever that means
           ::aDbs[1] := ::cPrepDbf
           cDriver := if(Left(::cTempFileDir,2) $ "C:" , "DBFCDX" , NIL )
           NetUse( ::cPrepDbf, 5 , cDriver ,USE_EXCLUSIVE,,::cTempFileDir )
           cIndExpr := SELF:IndexTempFile()
           ::lCustFile := TRUE
        ELSE
           SetTheDevices(1)
           scrnPop()
           RETURN(.F.)
        ENDIF
ENDCASE

IF LastKey() = K_ESC
   xKey := Alert( "You pressed ESC.;Do you want to stop?" , {"No" , "Yes" }, ALERT_WARN )
   IF xKey = 2
      SetTheDevices(1)
      ScrnPop()
      RETURN(.F.)
   ENDIF
ENDIF
*
*   ���� �� ����� ��� ������ ,�"��� ����������� �� ���� �� ���� aGetBuffer
*                                          .aMyBuffer � ������ �����������
*
IF nKey == NIL .or. nKey == 2
     FOR i := 1 TO LEN( ::aGetBuffer )
          AADD( ::aMyBuffer, GetBuffer( ::aGetBuffer[i] ))
     NEXT
ENDIF
*
* YH 7-8-00
* cbPrepShort ���� instance � ��� ����� �� ������ ����� ����� �����
*
IF VALTYPE(SELF:cbPrepShort)=='B'
   EVAL(SELF:cbPrepShort())
ENDIF
*
* ����� ��� "Screen" �� "Spreadsheet" �� "Report" ���� ::cDevType
*
::cDevType := GetDevType()
IF ::cDevType == "SpreadSheet"
     Self:SpreadSheet()
ELSEIF ::cTypeOfReport == "V7EXPORT"
     Self:V7Export()
ELSE
     ::nDest := self:GetDestin()
     IF ::cTypeOfReport == "REPORT"
     *
     * YG 1/3/98 determining which report to use if the is a list of reports in aReports
     *
     IF LEN(::aReports) <> 0  // �"��� ������ ��� Tvr � ���� ����
        SET EXACT ON
        *
        * � ����� ��� ��"�� ������� �� ���� �� ���� aSortList ���� Instance �
        * ������ ���� �"��� Sorting � �� �� ����� GetSortType() .oRep:SetSort
        *                                             .������.�� �� i � �����
        *
        i = ASCAN(::aSortList,GetSortType())
        SET EXACT OFF
        IF i <> 0
           IF !EMPTY(::aReports[i])
              *
              * (Rh2) Tvr � ���� �� ����
              *
              ::cRepFileName := ::aReports[i]  // rh2 ����
              ::cReportName  := ::aReports[i]
           ELSE
              // use the default repfile
           ENDIF
        ENDIF
     ENDIF
     Self:Print( , , ,lSeeMessage) //vitaly for sched 19.09.2000
     ELSE
          Self:Query()
     ENDIF
ENDIF

SetTheDevices(1)
prnKillCrit()
scrnPop()
genCloseFiles(::aDBS)
RETURN TRUE

********************
METHOD SpreadSheet(cSpreadFile,lMessage)
********************
LOCAL cSCR := SaveScreen( 2,0,2,79)
LOCAL CDBF,aTemp := {},cFields := ""
LOCAL aFieldNames, aTypes, i, cTemp, cFieldName
PRIVATE  aTestBlocks,aBuffer,cCmd
default cSpreadFile to GetSpreadFile()
        aTestBlocks := ::aTstBlocks
        aBuffer     := ::aMyBuffer

  @ 2,0 SAY Padr( "Creating spreadsheet file..." , 80 ) COLOR "W+/R"
   IF ::lPrepDbf
       SELF:CreateCondDb(,lMessage)
       cDBF := ::cPrepDBF
       ::aDBS[1] := ::cPrepDBF
   ENDIF
     GenOpenFiles(::aDBs)
     IF VALTYPE(::cbSetRelation)=="B"
         EVAL(::cbSetRelation,Self)
     ENDIF
   SELECT SELECT(::aDbs[1])
    IF VALTYPE(::cbPreQuery)=="B"
        EVAL(::cbPreQuery,Self)
    ENDIF
   SELECT SELECT(::aDbs[1])
   IF ::lPrepDbf   // No need for condition
       IF ::cBaseIndex # NIL
          cDBF  := ::aDbs[1]
          (cDBF)->(ORDSetFocus(::cBaseIndex))
       ENDIF

		 IF !empty(::aShortShow) .AND. "compact" $ getSortType()
		     FOR i := 1 TO len(::aShortShow)
		   		aadd(aTemp,::aFldList[::aShortShow[i]])
		     NEXT

		     ::aFldList := aTemp
		     aTemp := {}

		     FOR i := 1 TO len(::aShortShow)
		      	aadd(aTemp,::aTitles[::aShortShow[i]])
		     NEXT

		     ::aTitles := aTemp
		     aTemp := {}

		 ENDIF

		 Lexport( ( ::cTempFileDir+cSpreadFile) ,aclone(::aFldList) ,::aTitles,,"E4")


		 if ::cRepFileName $ "RPQC03V1_RPQC03VU" .AND. "compact" $ ::CSORTTYPE
			 COPY FIELDS exp_qty,esn_id TO (::cTempFileDir+cSpreadFile+".csv") DELIMITED
		 else
			 COPY TO (::cTempFileDir+cSpreadFile+".csv") DELIMITED
		 endif
	 ELSE
       IF ::cBaseIndex # NIL
          cDBF  := ::aDbs[1]
          (cDBF)->(ORDSetFocus(::cBaseIndex))
       ENDIF
		 IF !empty(::aShortShow) .AND. "compact" $ getSortType()
			  FOR i := 1 TO len(::aShortShow)
					aadd(aTemp,::aFldList[::aShortShow[i]])
			  NEXT

			  ::aFldList := aTemp
			  aTemp := {}

			  FOR i := 1 TO len(::aShortShow)
			   	aadd(aTemp,::aTitles[::aShortShow[i]])
			  NEXT

			  ::aTitles := aTemp
			  aTemp := {}

		 ENDIF
		 Lexport( ( ::cTempFileDir+cSpreadFile) ,ACLONE(::aFldList) ,::aTitles,"FOR SHAICOND(aTestBlocks)","E4")
		 COPY TO (::cTempFileDir+cSpreadFile+".csv") DELIMITED FOR (SHAICOND(aTestBlocks))
   ENDIF
   RESTSCREEN( 2,0,2,79,cSCR )

RETURN Self

********************
METHOD V7Export()
********************
//YG 12/24/97 copied from spreadshit
LOCAL cSCR := SaveScreen( 2,0,2,79)
LOCAL CDBF

PRIVATE  aTestBlocks,aBuffer
aTestBlocks := ::aTstBlocks
aBuffer     := ::aMyBuffer
@ 2,0 SAY Padr( "Creating V7 file..." , 80 ) COLOR "W+/R"
IF ::lPrepDbf
   SELF:CreateCondDb()
   cDBF := ::cPrepDBF
   ::aDBS[1] := ::cPrepDBF
ELSEIF VALTYPE(::cbSetRelation)=="B"
     EVAL(::cbSetRelation,Self)
ENDIF
GenOpenFiles(::aDBs)
SELECT SELECT(::aDbs[1])
IF VALTYPE(::cbPreQuery)=="B"
     EVAL(::cbPreQuery,Self)
ENDIF
SELECT SELECT(::aDbs[1])
IF ::lPrepDbf   // No need for condition
   IF ::cBaseIndex # NIL
      cDBF  := ::aDbs[1]
      (cDBF)->(ORDSetFocus(::cBaseIndex))
   ENDIF
   * YG 12/24/97 following is the only real change from spreadsheet()
   (::cRepdbf)->(dbgotop())
   IF !((::cRepdbf)->(eof()))
      SELECT (SELECT(::cRepDbf))
      COPY TO ( ::cTempFileDir+getprintfile() ) SDF
      // following are Schlisells brilliant ideas
      //COPY TO ( "H:\v72005\" + getprintfile() ) SDF
      * changed from avxv798 SS 25.04.99
      * changed from avxv799 SS 12.04.00

      COPY file ( ::cTempFileDir+getprintfile()+".txt" ) to lpt1
   ENDIF
   * getprintfile()
   * Lexport( ( ::cTempFileDir+GetSpreadFile()) ,aclone(::aFldList) ,::aTitles,,"L2")

ELSE
     IF ::cBaseIndex # NIL
        cDBF  := ::aDbs[1]
        (cDBF)->(ORDSetFocus(::cBaseIndex))
     ENDIF
     (::repdbf)->(dbgotop())
     IF !((::cRepdbf)->(eof()))
        SELECT (SELECT(::cRepDbf))
        COPY TO ( ::cTempFileDir+getprintfile() ) SDF
        COPY file ( ::cTempFileDir+getprintfile()+".txt") to lpt1
     ENDIF
     * Lexport( ( ::cTempFileDir+GetSpreadFile()) ,ACLONE(::aFldList) ,::aTitles,"FOR SHAICOND(aTestBlocks)","L2")
ENDIF
RestScreen( 2,0,2,79,cSCR )

RETURN Self
********************************
Method PRINT( l2ndLoop, cNtxExp, lPrintSummary,lSeeMessage)//vitaly for sched 19.09.200
********************************
*
* This method bascilly does everything from creating the temp file to outputing it
* YG by the way, in the exec method above Print() is sent without arguments, OR PARAMETERS OR WHATEVER THEY ARE CALLED
* Yg In rpqc08v2 the parameters are sent to print()
*
LOCAL cOrigScreen := SaveVideo()
*
* ��"�� ������� �����
*
LOCAL oRP := rpNew( 4, 2, 24, 79, 120, 31 )

LOCAL uVar,oRDO, n
LOCAL cFileName,cDriver,cIndExpr
LOCAL fFuncName := ::cRepFileName+"()"
PRIVATE  aTestBlocks,aBuffer

aTestBlocks := ::aTstBlocks  // Rpqc##v#.prg->SetQueryBlocks
aBuffer     := ::aMyBuffer   // ������ ����������� ���� �� ����� �����������.��� ������.��� ����

DEFAULT lPrintSummary TO FALSE
DEFAULT l2ndLoop TO FALSE
DEFAULT cNtxExp  TO ""
*
* User � ������ �"��� ������
*
rpDataPath(  oRP, ::cTempFileDir )      //YG coulcn't find these functions
rpIndexPath( oRP, ::cTempFileDir )
rpSwapPath(  oRP, ::cTempFileDir )
@ 2,0 SAY Padr( "Loading report..." , 80 ) COLOR "W+/R"

IF TYPE(fFuncName)=="UI"
   oRP := &fFuncName.      //YG what is this period do? and what is being done to oRep?
ELSE
   *
   *  TVR � ������ ��� ��"�� ������� ���� �� ����� ���� ��������
   *
   oRP := rpQuickLoad( @oRP, ::cRepFileName )     // load report (rh2 ����) from disk
   rpUseFonts( oRP, .f. ) //YG another function of unknown location
ENDIF
oRP[ rpREPORT ][ rpREPORT_SHOW_COUNTER ] := .f.
IF (! ::lPrepDbf .and. ! l2ndLoop )
    rpQuerytBlock(oRP,"{||ShaiCond(aTestBlocks)}")
ENDIF
@ 2,0 SAY Padr( "Loading report..." , 80 ) COLOR "W+/R"
IF ::lPrepDbf
   oRDO :=rpGetRDO( oRP, IIF(cRepName == "RMRK06V2" ,::aDBs[2] ,::aDBs[1] ) )
   IF oRDO ==NIL
      oRDO :=rpGetRDO( oRP, ::cRepDbf) //YG another function of unknown location
   ENDIF
   *
   * ����� + ���� ����������� ������ ������� �� ����� ���� ���� �����
   *                                      ������ �"� ����� Sort � ���
   *
   cIndExpr := SELF:CreateCondDb(oRp,lSeeMessage)
   *
   * YG The Final Temp file is now alive and kicking
   *
   IF ! ::lCreateORP  //YG what is this for? set to false in init()
      *
      * �"��� ����� ����� �����
      *
      (::cPrepDbf)->( DBCLOSEAREA() )
      *
      *   Master � ���� �����
      *
      (::aDbs[1])->( DbCloseArea() )
      rpDBTable( oRDO ,::cTempFileDir+::cPrepDbf )  //YG joins the mysterious function club
      *
      * �"��� ����� ����� �����
      *
      rpMyDBOpen(oRP, oRDO )     //YG some super duper technical dbase bashing function
      IF SELECT(::cPrepDbf) # 0
         SELECT SELECT(::cPrepDbf) // ���� ����
      ELSE
         *YH
         * ! ���� ���� ����� ���� ���� ����� ���� ���� ���� �����
         *
         *SELECT SELECT(::adbs[1]) // Master ����
         IF SELECT(::adbs[1])==0
            DBUSEAREA(.T.,"DBFCDXAX",::adbs[1])
         ENDIF

         SELECT(::aDbs[1])
      ENDIF
      *
      * ������� ����� ����� �����
      *
      rpDBIndex(oRP, oRDO ,::cTempFileDir+::cPrepDbf,::cPrepDbf )//rpDBIndex(oRP, oRDO ,::cPrepDbf,::cPrepDbf )
      rpDBKeyTBlock( oRDO ,cIndExpr )
   ENDIF
ELSEIF l2ndLoop // handle the odd case of a 2 pass report
   oRDO :=rpGetRDO( oRP, ::aDBs[1] ) //YG mystery function
   IF oRDO ==NIL
      oRDO :=rpGetRDO( oRP, ::cRepDbf)
   ENDIF
   (::cPrepDbf)->( DbCloseArea() )
   (::aDbs[1])->( DbCloseArea() )
   rpDBTable( oRDO ,::cTempFileDir+::cPrepDbf )
   rpMyDBOpen(::aOrp, oRDO )
   IF Select(::cPrepDbf) # 0
      SELECT SELECT(::cPrepDbf)
   ELSE
      SELECT SELECT(::adbs[1])
   ENDIF
   rpDBIndex(::aOrp, oRDO ,::cTempFileDir+::cPrepDbf,::cPrepDbf )
   rpDBKeyTBlock( oRDO ,cNtxExp )
ENDIF
IF ::lCreateORP  //YG Shuwadah?
   oRP := Eval(::cbBuildRep,Self)
   rpUseFonts( oRP, .f. )
   oRP[ rpREPORT ][ rpREPORT_SHOW_COUNTER ] := .f.
ENDIF
IF ::nDest == rpHTML
   * HTML output - let TVR generate a normal text file first,
   * then convert it to HTML after rpGenReport() finishes.
   rpDestination( oRP, rpPRINTER_FILE )
   rpPrinter( oRP, "ASCII" )
   rpOutFile( oRP, Alltrim( ::cTempFileDir + GetPrintFile() ) )
ELSE
   rpDestination( oRP,::nDest)
ENDIF
IF ::nDest == rpPRINTER_FILE
   uVar:= ::cTempFileDir+GetPrintFile()
   rpPrinter( oRP ,GetDefPrn() )
   rpOutFile( oRP, alltrim( uVar ) )
ELSEIF ::nDest == rpPRINTER
   ::nOldPrinter := GetUserInfo():nActivePrinter
   rpPrinter( oRP ,GetPrinter() )
   RpinitPcodes(oRP)
ENDIF
rpSwapPath( oRP ,::cTempFileDir )
GenOpenFiles(::aDBs)
*  added the IF...END because under some combinations the app crashes on
*  Buffer == NIL in the called method
IF !Empty(lSeeMessage) .OR. (!l2ndLoop  .AND. (::nDest <> rpPRINTER .OR. Alert("Print Summary list?",{"Yes","No"}) == 1)) .OR. lPrintSummary
   Self:AddSummary(oRP)
END
//fix bug for TVR(RPQC35V1,RPQC36V1 ONLY) from VR 10.04.02 id:2413541
IF (oRP[4][1][2] == "T_PQC35" .OR. oRP[4][1][2] == "T_PQC36" .OR. oRP[4][1][2] == "T_PQC391") .AND.;
   oRP[5][35][1][2] <> oRP[4][1][2]
   oRP[5][35][1][2] := oRP[4][1][2]
ENDIF
::aOrp := oRP
*
* �"��� ����
*
rpGenReport( oRP )       // generate report output


IF ::nDest == rpHTML
   * TVR wrote a text file via rpPRINTER_FILE - convert it to HTML
   uVar := Alltrim( ::cTempFileDir + GetPrintFile() )
   TextToHtml( uVar, uVar + ".html" )
   * FERASE( uVar )   // DEBUG: keep text file for encoding check
ELSEIF ::nDest == rpPRINTER_FILE
   fn_fLPTCap()
ELSEIF ::nDest == rpPRINTER
   IF ::nOldPrinter # GetUserInfo():nActivePrinter
      SetNewPrinter(::nOldPrinter )
   ENDIF
ENDIF
rpKillSorts( oRP )                            // kill any sort files
rpCloseData( oRP )                          // close report databases
RestVideo( cOrigScreen )
KEYBOARD CHR(0)
INKEY()
RETURN( NIL )

**************
METHOD Query()
**************
LOCAL cSCR  := SaveScreen( 2,0,24,79)
LOCAL CDBF
LOCAL oBc,aOldList
PRIVATE  aTestBlocks,aBuffer
aTestBlocks := ::aTstBlocks
aBuffer     := ::aMyBuffer
aOldList    := SetHlpKeys( ::aKeyList )
@ 2,0 SAY Padr( "Creating Query file..." , 80 ) COLOR "W+/R"
IF !::lUseScope   //YG set to false in init()
   IF IsThereCond()
      ::lPrepDbf := TRUE
   ENDIF
   IF ::lPrepDbf
      Self:CreateCondDb()   //YG creates temp file filtered and processed
      cDBF := ::cPrepDBF
      ::aDBS[1] := ::cPrepDBF    /* YG sets the newly created temp file as the leading file
                                    YG the print method doesn't do that!  Isn't that interesting!
                                    YG Naughty naughty, inconsistant and confusing!
                                    YG does a new index get built for this? */
   ENDIF
ENDIF
IF VALTYPE(::cbPreQuery)=="B"
   EVAL(::cbPreQuery,Self)       //YG do futher process on the temp file?
ENDIF
GenOpenFiles(::aDBs)
SELECT SELECT(::aDbs[1])
cDbf :=  ::aDBS[1]
@ 2,0 SAY Padr( "  " , 80 ) COLOR "W+/B"
oBc := BroCenter():new( cDbf , ::aFldList,,::aTitles,,,::lUseScope )
oBc:oForm :=  Form():new(,,,, ::cRepTitle,, ProcName() )
oBc:createBrowse():addDefaultCols()
If ::Freeze > 0
   oBc:oBro:Freeze := ::Freeze
ENDIF
IF ::lUseScope    //YG Shuwadah?
   ::GetTheScopt()
   (cDbf)->(ORDSetFocus(::cBaseIndex))
   (cDbf)->( DBGOTOP())
   IF ::cTop <> NIL .AND. ::cBottom <> NIL
      oBc:Re2Scope( ::cTop, ::cBottom )
   ENDIF
ELSEIF !::lPrepDbf .and. !::lCustFile
   IF ::cBaseIndex # NIL
      cDbf  := ::aDbs[1]
      (cDbf)->(ORDSETFOCUS(::cBaseIndex))
      (cDbf)->( DBGOTOP())
   ENDIF
ENDIF
oBc:bKey := COMPILE( (oBc:cFileName)->(ordKey()) )
oBc:ApplyBlock := {|nKey , o , oForm | QueryApplayKey(nKey,o,oForm ) }
IF ::cBaseIndex == NIL
   oBc:lCanAltS := FALSE
ELSE
   oBc:lCanAltS := TRUE
   IF ::lMultiIndex
      oBc:aIndexList     := ::aSortName
      oBc:aIndexCaptions := ::aSortList
   ENDIF
ENDIF
oBc:oForm:SayBottom( 24,0,Space(80) , NIL,"GR+/RB"  )
oBc:oForm:SayBottom( 24,0,"Help[F1] Ex.Help[ALT+F1]" , NIL,"GR+/RB"  )
IF ::cRepBotTitle <> NIL
   oBc:oForm:SayBottom( 24, 26, PADC(::cRepBotTitle,50), NIL,"W+/B" )
ENDIF
oBc:process()
oBc:oForm:hide()
SetHlpKeys( aOldList )
RestScreen( 2,0,24,79,cSCR )
RETURN SELF

*******************
Method  GetDestin()
*******************
LOCAL nRet
Do Case
  Case ::cDevType == "Printer"
    nRet := rpPRINTER
  Case ::cDevType == "Screen"
    nRet := rpDISPLAY
  Case ::cDevType == "File"
    nRet := rpPRINTER_FILE
  Case ::cDevType == "HTML"
    nRet := rpHTML
ENDCase
RETURN nRet

************************
METHOD CreateCondDb(oRp,lSeeMessage)//vitaly for sched 19.09.2000
LOCAL cDriver,cIndExpr := ""
LOCAL cDBF := ::adbs[1] // Master ����
LOCAL cTmpDbfile
LOCAL cSeek
LOCAL nWhichIndex  := 0   // YG 11/10/97 for supersmart
LOCAL cIndexType   := "regular"   // YG 20/11/97 for supersmart
LOCAL aTestResults := {}
LOCAL nTheWinner, nTheTempNo, i   := 0
LOCAL cChosenIndex := ""
LOCAL cMyBuffer    := ""
LOCAL cTarget := ""

IF VALTYPE(::cbPrepDBF) == "B" .AND. ::lBuildDBF
   EVAL(::cbPrepDBF,Self,orp) // Rpqc##v#.prg � ������ ���� ���
ELSE
   GenOpenFiles({cDBF})  //YG open leading file
   IF VALTYPE(::cbSetRelation)=="B"
      GenOpenFiles(::aDBS)
      EVAL(::cbSetRelation,Self)
   ENDIF
	if GetUserInfo():cWipCardNo <> "00000000EE00" .AND. ::cTypeOfReport == "REPORT"
      ::oScrl := ScrollBox():new( 4 ,25 , 11,  43 , "Filtering...", "W+/BG")
	endif
   IF(::cPrepDbf==NIL , ::cPrepDbf := "r_xx"+GetUserInfo():ConnNum(),NIL)  // Server + connection
   SELECT SELECT(::aDbs[1])
   cTmpDbfile := ::cTempFileDir+::cPrepDbf+".DBF" // ����� + ����� ����� ����
   IF  FILE(cTmpDbfile)
       IF SELECT(::cPrepDbf)#0
          (::cPrepDbf)->(DBCLOSEAREA())
       ENDIF
       FERASE(cTmpDbfile)
   ENDIF
   IF ::SmartSelect .and. ! Empty(::aMyBuffer[::nSmartCriteria ][1])
      (::aDbs[1])->(OrdsetFocus(::SmartIndex))
      cSeek := GetPropType(::aMyBuffer[::nSmartCriteria ][1])
      IF Len(::aMyBuffer[::nSmartCriteria ]) >2   //YG one smartindex, 2 fields to search for
         cSeek := cSeek + GetPropType(::aMyBuffer[::nSmartCriteria ][2])
      ENDIF
      (::aDbs[1])->(Dbseek(cSeek,.t.))
      ERASE(::cTempFileDir+::cPrepDbf)

      COPY TO (::cTempFileDir+::cPrepDbf) WHILE EVAL(::aTstBlocks[::nSmartCriteria ]) ;
       FOR ShaiCond(::aTstBlocks,::oScrl,recno(),::cTypeOfReport == "REPORT");
        .AND.IF(VALTYPE(::cbExtraCond)=="B",Eval(::cbExtraCond),.T.)
   ELSEIF ::lSuperSmart //.AND. .F.  //.and. CheckSuperSmart(self,nWhichIndex)  //YG 11/10/97 for supersmart indexing
      FOR nWhichIndex := 1 TO alen(::aSuperCriteria)
          IF  ( ::aSuperIndexes[nWhichIndex][2] ) //preventing array crash i.e. amybuffeer isn't always 2 dimensions
              IF  ( ::aSuperIndexes[nWhichIndex][2] ) .AND. ! empty(::aMyBuffer[::aSuperCriteria[nWhichIndex]][1])
                  * if we have a "to from" index - forget the rest and use it right away
                  cIndexType := "fromto"
                  EXIT
              ENDIF
          ENDIF
          IF !(::aSuperIndexes[nWhichIndex][2]) .AND. ! empty(::aMyBuffer[::aSuperCriteria[nWhichIndex]])
             (::aDbs[1])->(ordsetfocus(::aSuperIndexes[nWhichIndex][1]))
             cSeek := GetPropType(::aMyBuffer[::aSuperCriteria[nWhichIndex]])
             IF SUBSTR(cSeek,1,1) <> "_"
                cSeek := substr(cSeek,1,at("_",cSeek)-1)
             ELSE      //Oh Oh, we have an unusual case. "_" is before the criteria
                * getting rid of the first "_"
                cSeek := substr(cSeek,2)+"_"
                * now cSeek is like the usual case
                cSeek := substr(cSeek,1,at("_",cSeek)-1)
             ENDIF
             * lets build a list of the length of each criterion list
             * we will use it later to decide which criterion to index and searh on
             IF (::aDbs[1])->(Dbseek(cSeek,.t.))
                  aadd(aTestResults,{nWhichIndex,len(::aMyBuffer[::aSuperCriteria[nWhichIndex]])})
             ELSE
                  AADD(aTestResults,{nWhichIndex,0})
             ENDIF

          ELSE //if the buffer is empty we set recno to 0
             *
             * aSuperCriteria � nWhichIndex � ����� �������� ���� ��� �� .T. ����� ������ ��
             * (aMyBuffer � ��������� ���� ���� ���� ����� 0 �� ���� aTestBlocks � ������
             *
             AADD(aTestResults,{nWhichIndex,0})
          ENDIF
      NEXT
      IF cIndexType == "fromto"  //lets do a standard smart index copy
         (::aDbs[1])->(OrdsetFocus(::aSuperIndexes[nWhichIndex][1]))
         cSeek := GetType2(::aMyBuffer[::aSuperCriteria[nWhichIndex]][1])
         IF cSeek <> NIL
            *
            *               if (::aDbs[1])->(Dbseek(cSeek,.t.))
            * YG 7/12/97 this was a safety hatch but I took it out caz often you use a from value which doesn't exist and
            * chaval to dump the smart copy because of those not uncommon cases
            * therefore this copy should be identical to the standard smart copy from..to
            * cSeek := GetPropType(::aMyBuffer[::nSmartCriteria ][1])
            *
            IF LEN(::aMyBuffer[::aSuperCriteria[nWhichIndex]]) >2   //YG 14.6.98 ADDED LIKE IN REGULAR SMART
                                                                       //example: from to with date and time where there are 4 criteria
               cSeek := cSeek + GetPropType(::aMyBuffer[::aSuperCriteria[nWhichIndex] ][2])
            ENDIF
            (::aDbs[1])->( Dbseek(cSeek,.t.) )
            ERASE(::cTempFileDir+::cPrepDbf)
            COPY TO (::cTempFileDir+::cPrepDbf) WHILE EVAL(::aTstBlocks[::aSuperCriteria[nWhichIndex]]) ;
                   FOR ShaiCond(::aTstBlocks,::oScrl,recno(),::cTypeOfReport == "REPORT");
                   .AND.IF(VALTYPE(::cbExtraCond)=="B",Eval(::cbExtraCond),.T.)
         ELSE // something went wrong, do a stupid copy from the top
            (::aDbs[1])->( DbGoTop() )
            ERASE(::cTempFileDir+::cPrepDbf)
            COPY TO (::cTempFileDir+::cPrepDbf) ;
                     FOR ShaiCond(::aTstBlocks,::oScrl,recno(),::cTypeOfReport == "REPORT");
                     .AND.IF(VALTYPE(::cbExtraCond)=="B",Eval(::cbExtraCond),.T.)
         ENDIF
      ELSEIF cIndexType == "regular"
         *
         * finding which index gave us the shortest aMyBuffer
         * YG 26.5.98 we secided that we will start from the last index and work up
         *
         nTheWinner := 0
         nTheTempNo := 999999     //a number longer than any length of ::aMyBuffer[?]
         *
         * (aTestResults>0) Date ������ ����� ����� ������ ��������� �����
         *
         FOR nWhichIndex := alen(::aSuperCriteria) to 1 step -1
             IF aTestResults[nWhichIndex][2] <>  0 //i.e. the index finds something
                *
                * ������� ����� aSuperCriteria � ������ ��������� �� ����� ����
                *                                      .nTheWinner ������ �����
                *
                nTheWinner := nWhichIndex
                *
                * nTheTempNo � �"�� ��������� ���� ���� ���� ����
                *
                nTheTempNo := aTestResults[nWhichIndex][2]
                EXIT
             ENDIF
         END
         *
         *  ���� ����� �������� ���� ��
         *
         IF nTheWinner <> 0 .AND. nTheTempNo <> 0 //we have a winner!
            *
            * aSuperIndexes � nTheWinner � ����� Tag � ��� ������ Master � ����
            *
            (::aDbs[1])->(OrdSetFocus(::aSuperIndexes[nTheWinner][1]))
            *
            * aSuperIndexes � Tag � ��� Master � ���� ����� ����� ��������� ���� �� ���� cMyBuffer
            *
            cMyBuffer := GetPropType(::aMyBuffer[::aSuperCriteria[nTheWinner]])
            *
            * cutting the first expresion from the amybuffer string of chosen criteria
            *
            IF SUBSTR(cMyBuffer,1,1) <> "_"
               * cMyBuffer := substr(cMyBuffer,1,at("_",cMyBuffer)-1)
            ELSE      //Oh Oh, we have an unusual case. "_" is before the criteria
               cMyBuffer := substr(cMyBuffer,2)//+"_"
               IF RIGHT(cMybuffer,1) <> "_"
                  cMybuffer := cMybuffer + "_"
               ENDIF
            ENDIF
            cSeek := SUBSTR(cMybuffer,1,at("_",cMyBuffer)-1)
            *
            * cMyBuffer� ������ ��������� "�����"
            *
            cMyBuffer := substr(cMybuffer,at("_",cMyBuffer)+1)
            cChosenIndex :=  (::aDbs[1])->(ORDKEY(0))  // ������ Tag �
            *
            * ������� ������ ������ ���� �����
            *
            IF "+" $ cChosenIndex   //cutting the first expression, otherwise leave as is
               cChosenIndex := left(cChosenIndex,at("+",cChosenIndex)-1)
            ENDIF
            *
            * ������� ������ ������ ����� "PADR(" �����
            *
            IF UPPER(SUBSTR(cChosenIndex,1,5)) == "PADR("  //cutting the function padr
               cChosenIndex := substr(cChosenIndex,6)
            ENDIF
            IF (::aDbs[1])->(Dbseek(cSeek,.t.))
               @2,44 say cSeek
               ERASE(::cTempFileDir+::cPrepDbf)
               *
               * ����� ����� ����� ������ ����������� ������ ������� �� �����
               *
               COPY TO (::cTempFileDir+::cPrepDbf) ;
                      WHILE getValue(cChosenIndex) == cSeek  ;
                        FOR ShaiCond(::aTstBlocks,::oScrl,recno(),::cTypeOfReport == "REPORT") ;
                        .AND.IF(VALTYPE(::cbExtraCond)=="B",Eval(::cbExtraCond),.T.)
               * Ok, we finished creatting the file by copying the first criterion, now lets do the rest
               * for i := 1 TO FCOUNT()
               *  temp_dbf->(FIELDPUT(i, source_dbf->(fieldget(i)))))
               NetUse( ::cPrepDbf, STD_RETRY, , USE_EXCLUSIVE, USE_NEW, ::cTempFileDir )
               SELECT(SELECT(::aDbs[1]))
               WHILE "_" $ cMyBuffer    //while cutting away at the cMyBuffer one criterion at time
                     cSeek := substr(cMybuffer,1,at("_",cMyBuffer)-1)
                     (::aDbs[1])->(Dbseek(cSeek,.t.))
                     * now we step through the abba file and check each record if it should be added to the temp file
                     @2,44 say cSeek
                     WHILE getValue(cChosenIndex) == cSeek //YG 16/03/99 I think here we have to add '.and. !eof()'
                           IF ShaiCond(::aTstBlocks,::oScrl,recno(),::cTypeOfReport == "REPORT") ;
                             .AND.IF(VALTYPE(::cbExtraCond)=="B",Eval(::cbExtraCond),.T.)
                              (::cPrepDbf)->( dbappend() )
                              FOR i := 1 TO FCOUNT()
                                  (::cPrepDbf)->(FIELDPUT(i,(::aDbs[1]) ->(fieldget(i))))
                              NEXT
                           ENDIF
                           (::aDbs[1])->(Dbskip())
                     END
                     cMyBuffer := substr(cMybuffer,at("_",cMyBuffer)+1)
                     * chopping off the first criterion in the string that we are already finished with
               END
               (::cPrepDbf)->( DBCLOSEAREA() )
               ERASE(::cTempFileDir+::cPrepDbf)
            ELSE // something went wrong, do a stupid copy from the top
               (::aDbs[1])->( DbGoTop() )
               *           ERASE(::cTempFileDir+::cPrepDbf)
               *
               * ����� ����� ����� ������ ����������� ������ ������� �� �����
               *
               COPY TO (::cTempFileDir+::cPrepDbf) ;
                   FOR ShaiCond(::aTstBlocks,::oScrl,recno(),::cTypeOfReport == "REPORT");
                    .AND.IF(VALTYPE(::cbExtraCond)=="B",Eval(::cbExtraCond),.T.)
            END
         ELSE //do a regular copy - no criteria chosen that we can supersmart index on
              (::aDbs[1])->( DbGoTop() )
              * ERASE(::cTempFileDir+::cPrepDbf)
              *
              * ����� ����� ����� ������ ����������� ������ ������� �� �����
              *
              COPY TO (::cTempFileDir+::cPrepDbf) ;
                   FOR ShaiCond(::aTstBlocks,::oScrl,recno(),::cTypeOfReport == "REPORT");
                   .AND.IF(VALTYPE(::cbExtraCond)=="B",Eval(::cbExtraCond),.T.)
         ENDIF
      ENDIF
      ****************************************
      // Ad Kahn SuperSmart Stuff
      ****************************************
   ELSE  //YG no smartindex set, do stupid copy
         ERASE(::cTempFileDir+::cPrepDbf)
         *
         * ����� ����� ����� ������ ����������� ������ ������� �� �����
         *
         COPY TO (::cTempFileDir+::cPrepDbf) ;
         FOR ShaiCond(::aTstBlocks,::oScrl,recno(),::cTypeOfReport == "REPORT");
          .AND.IF(VALTYPE(::cbExtraCond)=="B",Eval(::cbExtraCond),.T.)
   ENDIF
	if GetUserInfo():cWipCardNo <> "00000000EE00" .AND. ::cTypeOfReport == "REPORT"
		::oScrl:hide()
	endif
   *
   * ...���� ���� ���� ��� �� ��� ����� ����
   *
   (cDbf)->( DBCLOSEAREA() )
   ::lPrepDbf := TRUE  // We don't need to send the condition to The reportwriter or spreadsheet.
   *
   *   �� Rpqc##v1.prg->oRep:cbPrepDbf � CodeBlock ���� cbPrepDBF :���� Instance �
   *  ����� ����� ���� ����� �� ������ ����� ����� ���� ���� ����� ����
   *   .������ �� ������ �������� ����� �"�� ���� ���� ���� .���� �����
   *
   IF VALTYPE(::cbPrepDBF)=="B"
      *
      * (Rpqc##v#.prg->oRep:cbPrepDbf �������� ����� ������� �"��� ������� ���� �����
      *
      EVAL(::cbPrepDBF,Self,oRp)
   ENDIF
   IF  SELECT(::cPrepDbf)>0
       (::cPrepDbf)->(DBCLOSEAREA())
   ENDIF
   cDriver := if(Left(::cTempFileDir,2) $ "C:" , "DBFCDX" , NIL )
   IF FILE(::cTempFileDir+::cPrepDbf + ".cdx")
      * FERASE (::cTempFileDir+::cPrepDbf + ".cdx") //vr ASK FOR SHAI!!!
   ENDIF
   *
   * (����������� ������ ������ �� ����) �"��� ����� ����� �����
   *
   NetUse(::cPrepDbf , 5 , cDriver ,USE_EXCLUSIVE,,::cTempFileDir )

   *IF (::cPrepDbf)->( EOF() ) .AND. (::cPrepDbf)->( BOF() )
   *YH
   *  ! ���� ����  ��
   *
   IF (::cPrepDbf)->(LASTREC())==0 .AND. Empty(lSeeMessage)
      ALERT("No Records;;No records found for this criteria",{" OK "})
   ENDIF
   //wait//vitaly
   IF ::lDoindex
      cIndExpr := SELF:IndexTempFile()    //create new index for final file
   ENDIF
ENDIF
RETURN cIndExpr

**********************
METHOD IndexTempFile()
**********************
LOCAL nPos, i
LOCAL nLastRec := 0      //added by
PRIVATE  cIndExp:=""
IF LEN(::aSortExpr)>0
     ::cSortType := GetSortType()
     nPos        := ASCAN(::aSortList,{|aVal| aVal ==::cSortType })
     IF nPos == 0
          nPos := 1
     ENDIF
     cIndExp     := ::aSortExpr[nPos]
     IF ::lRelIndex
          IF VALTYPE(::cbSetRelation)=="B"
               GenOpenFiles(::aDBS)
               Select Select(::cPrepDbf)
               EVAL(::cbSetRelation,Self)
          ENDIF
     ENDIF
     Select Select(::cPrepDbf)
     IF !Empty( cIndExp )
          nLastRec := LastRec()         //added by

      //    CheckIndex(::cPrepDbf,::cTempFileDir+::cPrepDbf,cIndExp,.T.)
          //COPY FILE (::cPrepdbf + ".cdx") TO  (::cTempFileDir+::cPrepDbf + ".cdx")
          INDEX ON &cIndExp  TAG (::cPrepDbf) TO (::cTempFileDir+::cprepdbf) EVAL NtxProgress(nPos,nLastRec)         //changed by
     ENDIF
ENDIF
RETURN cIndExp

**********************
Method AddSummary(oRP)
**********************
LOCAL i,nLen,nTmp,nRow,cFileName,aLines
LOCAL oSummary
    cFileName := oRP[rpDATABASE][1][rpDATABASE_ALIAS]
    aLines    := aPrnCritPage( (cFileName)->(ordKey()) )
    nLen      := Len(aLines)
    nRow      := len( oRP[ rpLINES ] )
    FOR   i := 1 to nLen
        nRow++
        oSummary := rpLinePlace( oRP, nRow, RP_SUMMARY,   1,.f.,.f.,[{||.t.}] ,  31, .f. )
        nTmp := rpRFldNew( oRP, "__TEXT__", "TEXT", "C", LEN(aLines[i]), 0, aLines[i] )
        rpLFieldNew( oSummary, 1, nTmp, , , , , )
    NEXT
    IF VALTYPE(::cRemark) =="C"
        nRow++
        oSummary := rpLinePlace( oRP, nRow, RP_SUMMARY,   1,.f.,.f.,[{||.t.}] ,  31, .f. )
        nTmp := rpRFldNew( oRP, "__TEXT__", "TEXT", "C", LEN(::cRemark), 0, ::cRemark )
        rpLFieldNew( oSummary, 1, nTmp, 1)
    ENDIF
        nRow++
        oSummary := rpLinePlace( oRP, nRow, RP_SUMMARY,   1,.f.,.f.,[{||.t.}] ,  31, .f. )
        nTmp := rpRFldNew( oRP, "__TEXT__", "TEXT", "C", 1, 0, " " )
        rpLFieldNew( oSummary, 1, nTmp, 1)

   rpRebuildDisp(oRP)

RETURN Self

********************
METHOD GetTheScopt()
********************
Local uVal
Default ::nScopeOn TO 1

uVal := ::aMyBuffer[::nScopeOn]

IF LEN(uVal) > 1
   ::cTop    := uVal[1]
   ::cbottom := uVal[2]
ELSE
   ::cTop    := uVal[1]
   ::cbottom := uVal[1]
ENDIF

Return Self

Function RepName()
Return cRepName

Function SetRepName(cRep)
Return cRepName := cRep

******************************
Static Function PopMenu(aMenu)
******************************
LOCAL nMenu
  LOCAL cClr         := SETCOLOR( "w+/bg,gr+/r" )
  LOCAL cScr         := SAVESCREEN()
  @ 11, 25 CLEAR TO 15, 65
  DrawBox( 11, 25, 15, 65 )
  SETCURSOR(1)
  @11, 26 SAY PADC("Choose search method:",39) COLOR "n/RB"
  @ 13,27 PROMPT  Padc(aMenu[1,1],38)
  @ 14,27 PROMPT  Padc(aMenu[2,1],38)
  MENU TO nMenu

  SETCOLOR(cClr)
  RESTSCREEN(0,0,24,79,cScr)
RETURN nMenu

**************************
Function GetType2(Uval)
**************************
LOCAL uRetVal
LOCAL cType := VALTYPE( uVal )
DO CASE
   CASE  cType $ "CL"
         uRetVal := uVal
   CASE  cType == "D"
         uRetVal := Dtos(uVal)
   CASE  cType == "N"
         uRetVal := str(uVal)
ENDCASE
RETURN uRetVal

**************************
FUNCTION GetPropType(Uval)
**************************
*
* ���� �� ����� �������� Date ���� ��� ��������� �� ,��������� ��� ��� Uval
*                                                          .STRING Format �
*
LOCAL uRetVal
LOCAL cType := VALTYPE( uVal )
DO CASE
   CASE  cType $ "CNL"
         uRetVal := uVal
   CASE  cType == "D"
         uRetVal := Dtos(uVal)
ENDCASE
RETURN uRetVal
***************************************************
Function QueryApplayKey(nKey , oBroCenter , oForm )
***************************************************
LOCAL lProcessed := .T.
LOCAL cSubtitle := ""

DO CASE

         CASE nKey == K_ALT_F1
                   prnHelpCrits()
         CASE nKey == K_F3
         cSubtitle := FillSubTitle(oMyRep,oMyRep:aSubtiltle)
         SetKotMsg(oMyRep:cRepTitle,{32,32},"User :"+GetUserInfo():cUserId+" "+;
                  "---------- Query :"+ " "+oMyRep:cReportName,;
                   cSubTitle ,prnGetUserMsg() )
            SetFileToPrint(oMyRep:cReportName+".DOC")
            TbPrint(oBroCenter:oBro,"",{|| "" },TRUE)
            IF LastKey() == K_ENTER
               SendToPrinter(FileToPrint(),.F.)
            END
          CASE  ValType(oMyrep:QApplyKeys) == "B"
              oMyRep:QApplyKeys:eval(nKey , oBroCenter , oForm )

   OTHERWISE
       lProcessed := .F.
ENDCASE

RETURN lProcessed

function getvalue(cFieldName)
local retval
retval = &cFieldname
return retval

Function GetRepFileName()
Return oMyRep:cRepFileName