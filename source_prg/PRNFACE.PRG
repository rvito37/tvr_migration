// prnface.prg
// Function/Procedure Prototype Table  -  Last Update: 24-06-96 @ 14:59:39
// ��������������������������������������������������������������������������
// Return Value         Function/Arguments
// �������������������  �����������������������������������������������������
// xRetVal              STATIC FUNCTION CreateVal( xVal )
// { cCritName, cType,  STATIC FUNCTION NextLine( cBuffer )
// StrZero( nLastNo...  STATIC FUNCTION NextName( cRepName )
// .T.                  STATIC FUNCTION SetPrnDest
// aValue               STATIC FUNCTION Turn2Arr( cTemp )
// .T.                  STATIC FUNCTION postUserMsg(o)
// Void                 STATIC PROCEDURE DefineDest
// Void                 STATIC PROCEDURE NewRepSet( cTitle , cRepName )
// Void                 STATIC PROCEDURE RedrawChecks( lCancel )
// Void                 STATIC PROCEDURE SaveSelections( cFile )
// NL Chr(10)+Chr(13)   STATIC PROCEDURE prnRestoreData( cRepDosFileName )
// Void                 STATIC PROCEDURE prnSaveData( cRepName )
// Void                 STATIC PROCEDURE prnShowRepSets( cRepName )
// Void                 PROCEDURE OutOfGet
// Void                 PROCEDURE PrnFace( aSortParams , aCutParams , aRepInfo , nSortDefault)
// Void                 PROCEDURE SetCheckBlocks( aCb )
// Void                 PROCEDURE TabGet
// Void                 PROCEDURE prnCritPage( cIndexKey )
// {"HP laser IV" ,;    FUNCTION AskPrinters
// cDeviceType          FUNCTION GetDevType
// .T.                  FUNCTION GetFile
// aCutIndicators       FUNCTION GetIndicators
// Alltrim(cPrintFile)  FUNCTION GetPrintFile
// cPrinter             FUNCTION GetPrinter
// cSortType            FUNCTION GetSortType
// .T.                  FUNCTION GetSpread
// Alltrim(cSpreadF...  FUNCTION GetSpreadFile
// {|x| iif(x == NI...  FUNCTION MakeBlock( aCutIndicators,i)
// cUserMsg             FUNCTION prnGetUserMsg

// G:\BMS\SOURCE\PRNFACE.PRG

#DEFINE rpBOLD                    1
#DEFINE rpITALIC                  2
#DEFINE rpUNDERSCORE              3
#DEFINE rpBOLD_ITALIC             4
#DEFINE rpBOLD_UNDERSCORE         5
#DEFINE rpBOLD_ITALIC_UNDERSCORE  6
#DEFINE rpITALIC_UNDERSCORE       7
#DEFINE rpATTR_NONE               8

#include "avxdefs.ch"

STATIC aSort , aCut , aCutDefault
STATIC aCutIndicators
STATIC aPrinters
STATIC cPrinter
STATIC nOldPrn
STATIC lPrinter := .f.

STATIC aDevices
STATIC nDevices := 1   // 1- Dani default ,2 - Shai Default ,3-Query

STATIC cSortType
STATIC cDeviceType

STATIC cPrintFile := "        " , cSpreadFile := "        "

STATIC aCheckBlock

STATIC cUserMsg , cTitle

STATIC cBoldOn, cBoldOff, cItalOn, cItalOff ,cUnderOn, cUnderOff


PROCEDURE PrnFace( aSortParams , aCutParams , aRepInfo , nSortDefault, cSubTitle, aSupercrits,lDest)
LOCAL i , nLen ,j , nHowMany
LOCAL lHasDefault := FALSE
local lsupercolor := .F.

DEFAULT nSortDefault TO 0
DEFAULT lDest TO TRUE

//cUserMsg := IF( cSubTitle == NIL, Space( 70 ), PADR(cSubTitle,70) )
cUserMsg := IF( cSubTitle == NIL, Space( 35 ), PADR(cSubTitle,35) )

aSort     := aSortParams
IF ! EMPTY(aSort)
    IF !Empty( nSortDefault )
       cSortType := aSort[nSortDefault]
    ENDIF
ENDIF

aCut      := aCutParams
aPrinters := AskPrinters()

SetKey( K_SH_F5 , { || prnSaveData(aRepInfo[1]) } )
SetKey( K_F5 , { || prnShowRepSets(aRepInfo[1]) } )
SetKey( K_F7 , { || prnShowCrits() } )
SetKey( K_TAB ,{ || TabGet() } )
//SetKey( K_F1  ,{ || prnHelpCrits() })

@ 0,0 SAY Padc( aRepInfo[2]+" ("+aRepInfo[1]+")" , 80 ) COLOR "GR+/RB"
@ 24,0 SAY Padr( "Help[F1] Load crit[F5] Save crit[Shift]+[F5] View crit[F7] Run[PgDn] Exit[Esc]" , 80 ) COLOR "GR+/RB"

nLen := Len( aCutParams )
aCutIndicators := Array( nLen )
aCutDefault    := Array( nLen )
Afill( aCutIndicators , .F. )
Afill( aCutDefault , .F. )

//s.b. Add load default crit.
// The File Should be the same as the Report/Query Name with extension ".Def"
// The file can be created via the regular  Saving feature and be
// rename  to the ".def" extension.

IF FILE(aRepInfo[1]+".def")
       prnRestoreData(aRepInfo[1]+".def",TRUE)
       lHasDefault := TRUE
ENDIF

IF nDevices == 1
   aDevices := { "Printer" , "File" , "SpreadSheet" , "HTML" }
ELSEIF nDevices == 2
   aDevices := { "Printer" , "File" , "Screen", "SpreadSheet" , "HTML" }
ELSEIF nDevices == 3
   aDevices := {"Screen", "SpreadSheet" , "HTML" }
ELSEIF nDevices == 4     //YG 12/24/97
   aDevices := {"V7 Export" }
ENDIF
cSpreadFile := aRepInfo[1]
cPrintFile  := aRepInfo[1]

@ 2 , 2 SAY "Optional subtitle:" COLOR "W+/B"
@ 3 , 2 GET cUserMsg COLOR GETCOLORS ;
                     SEND preBlock := {|o| SetCursor(1),.T. } ;
                     SEND postBlock := {|o| postUserMsg(o),.T. }

IF !Empty( aSort )
   //@ 5, 2 SAY  "Select sort rule:" GET cSortType WITH RADIOBUTTONS aSort NOBOX
   @ 4, 2 SAY  "Select sort rule:"  COLOR  "W+/B"
   @ 5, 4 GET cSortType RADIO aSort   // When {|| IF(Len(aSort)>1,t.,.f.)}
ENDIF
//   cDeviceType  := "Printer"
// @ 19, 2 SAY  "Select destination:" GET cDeviceType WITH RADIOBUTTONS aDevices NOBOX
IF lDest
    @ 18, 2 SAY  "Select destination:"
    IF nDevices == 1 .or. nDevices == 2
      cDeviceType  := "Printer"
    ELSEIF nDevices == 3
      cDeviceType  := "Screen"
    ELSEIF nDevices == 4
      cDeviceType  := "V7 Export"
    ENDIF
    @ 19, 4 GET cDeviceType RADIO aDevices
ENDIF
IF !Empty( nLen )
 //  @ 4,45 SAY "Select criteria:"  COLOR  "W+/B"     //changed by
   @ 2,45 SAY "Select criteria:"  COLOR  "W+/B"
ENDIF

  FOR i := 1 TO nLen
    //  SetPos(4+i, 45)    //changed by
      SetPos(2+i, 45)
      nHowMany := alen(getlist)
      j := 1
      lSupercolor := .F.
      while j <= alen(aSuperCrits)
          IF i == aSupercrits[j]
          //       getlist[i+nHowMany]:colordisp("r+/b,b/r")
               lSuperColor := .T.
          ENDIF
          J++
      end
      Aadd(GetList,;
      CheckGetNew(  MakeBlock( aCutIndicators ,i) , "aCutIndicators[i]", aCut[i],lSupercolor))
      IF ValType( aCheckBlocks ) == "A"
         Atail( GetList ):postBlock := aCheckBlocks[i]
         IF lHasDefault .and. aCutDefault[i]
            Atail( GetList ):ExitState := GE_NOEXIT
            KEYBOARD Chr( K_PGDN)
            EVAL(aCheckBlocks[i],Atail( GetList ))
            Atail( GetList ):ExitState := NIL
         ENDIF
      ENDIF

  NEXT

  READ
  IF EMPTY(cDeviceType)
     cDeviceType  := "Printer"
  ENDIF

  SetKey( K_SH_F5 , NIL )
  SetKey( K_F5 , NIL )
  SetKey( K_F7 , NIL )
  SetKey( K_TAB , NIL )
  SetKey( K_F2 , NIL )
  SetKey( K_F1, NIL )

  IF LastKey() = K_ENTER .OR. LastKey() = K_PGDN

    IF lDest
       DefineDest()
    ENDIF
  ELSEIF LastKey() = K_ESC
     SetCursor(0)
  ENDIF

RETURN

FUNCTION MakeBlock( aCutIndicators,i)
RETURN {|x| iif(x == NIL, aCutIndicators[i], aCutIndicators[i] := x) }


STATIC FUNCTION postUserMsg(o)
   SetCursor(0)
RETURN .T.

STATIC PROCEDURE DefineDest

DO CASE
   CASE cDeviceType  == "File"
        GetFile()
   CASE cDeviceType  == "SpreadSheet"
        GetSpread()
   CASE cDeviceType  == "Printer"
        SetPrnDest()
   CASE cDeviceType  == "Screen"
        SetDispDest()
   CASE cDeviceType  == "V7 Export"
        //v7export()
        GetFile()
   CASE cDeviceType  == "HTML"
        GetFile()
ENDCASE
RETURN

// this is temp proc
PROCEDURE OutOfGet
GetActive():ExitState := GE_WRITE
RETURN

FUNCTION AskPrinters

LOCAL aPrn := GetPrnArray()
LOCAL aPrinters := {}
LOCAL i

FOR i := 1 TO LEN( aPrn )
    AADD( aPrinters, aPrn[i][2] )
NEXT
/*
LOCAL aPrinters :={}
// s.b. get printer acording to user printer list from
// d_user.dbf
NetUse("PRinters",5)
printers->(DBSETINDEX("PRINTERS"))
DBEVAL({||AADd(aPrinters,FieldGet(FieldPos("PR_NAME")))})
DBCloseAREA()
*/
RETURN aPrinters
/*{"HP laser IV" ,;
        "Ink jet 850" ,;
        "Epson 1080 FX",;
        "xxxxxxxxxxx" ,;
        "vvvvvvvvv" }*/

Proc SetTheDevices(nDev)
nDevices := nDev
Return

FUNCTION SetFile
IF SUBSTR(cPrintFile, 1, 1) <> "X"
     cPrintFile := "X" + ALLTRIM(SUBSTR(cPrintFile, 2, 7))
ELSE
     cPrintFile := "Y" + ALLTRIM(SUBSTR(cPrintFile, 2, 7))
ENDIF
RETURN .T.

FUNCTION GetFile
LOCAL GetList := {}
@ 20, 20 GET cPrintFile  PICTURE "@!" COLOR GETCOLORS VALID !Empty( cPrintFile )
SET CURSOR ON
READ
SET CURSOR OFF
//IF LastKey() != K_ENTER
//   cPrintFile := "        "
//ENDIF
RETURN .T.


FUNCTION GetSpread
LOCAL GetList := {}

@ 19+LEN(aDevices)-1, 20 GET cSpreadFile  PICTURE "@!" COLOR GETCOLORS VALID !Empty( cSpreadFile )
SET CURSOR ON
READ
SET CURSOR OFF
//IF LastKey() != K_ENTER
//   cSpreadFile := "        "
//ENDIF
RETURN .T.

STATIC FUNCTION SetPrnDest
LOCAL GetList := {}
LOCAL nPrn

cPrinter :=  GetDefPrn() //aPrinters[1]  // "HP laser IV"

@ 19 , 20 GET COMBO cPrinter SEND colorSpec :=  GETCOLORS ;
          COMBO aPrinters;
          CBOCOLORS "w+/b,g+/r,,,w+/b" READONLY
READ
//IF LastKey() != K_ENTER
//   cPrinter := "        "
//ELSE
   nPrn := ASCAN( aPrinters, cPrinter )
nOldPrn :=   SetNewPrinter( nPrn )
lPrinter := .t.
//ENDIF
RETURN .T.

STATIC FUNCTION SetDispDest
RETURN .T.

PROCEDURE SetCheckBlocks( aCb )
aCheckBlocks := aCb
RETURN

FUNCTION GetSortType
RETURN cSortType

FUNCTION SetSortType(cSrtType)
RETURN cSortType := cSrtType

FUNCTION GetIndicators
RETURN aCutIndicators

FUNCTION GetDevType
RETURN cDeviceType

FUNCTION GetPrintFile
RETURN Alltrim(cPrintFile)

FUNCTION GetSpreadFile
RETURN Alltrim(cSpreadFile)

FUNCTION GetPrinter
RETURN cPrinter

STATIC PROCEDURE prnSaveData( cRepName )
LOCAL cTitle
LOCAL nLen := Len(aCutIndicators) , i

FOR i := 1 TO nLen
    IF aCutIndicators[i]
       EXIT
    ENDIF
NEXT

IF i > nLen
   Msg24( {"26"} , 3 , .T. )
   RETURN
ENDIF

cTitle := InPutBox( "Title:" , Space( 60 ),replicate("X",60), " Save new set ")

IF LastKey() = K_ENTER .or. LastKey() = K_PGDN
   NewRepSet(cTitle , cRepName )
ENDIF

RETURN

STATIC PROCEDURE NewRepSet( cTitle , cRepName )

IF NetUse( "repsets" , 5 )
   repsets->( ordsetfocus( "irepsets" ) )
ENDIF

IF repsets->( AddRec(5) )
   repsets->repname  := cRepName
   repsets->title    := cTitle
   repsets->repfile  := NextName( cRepName )
   SaveSelections( cRepName+"d."+repsets->repfile)
ENDIF

NETCLOSE repsets
RETURN

STATIC FUNCTION NextName( cRepName )
LOCAL aRepDir := Directory( cRepName+".0??" )  //up to 99 definitions per report
LOCAL nLastNo

IF Empty( aRepDir )
   nLastNo := 0
ELSE
   Asort( aRepDir ,,, {| x , y | Right(x[1],3) < Right( y[1],3 ) } )
   nLastNo := Val( Right( Atail(aRepDir)[1],3 ))
ENDIF

nLastNo++
RETURN StrZero( nLastNo , 3)

STATIC PROCEDURE SaveSelections( cFile )
LOCAL cDataFile := BuildCritData( aCut , aCutIndicators )
MemoWrit( cFile , cDataFile )
RETURN


STATIC PROCEDURE prnShowRepSets( cRepName )
LOCAL o , bKey , Searcher := Upper( cRepName )
LOCAL nkey
LOCAL cDelReport

scrnPush()

IF NetUse( "repsets" , 5 )
   repsets->( ordsetfocus( "irepsets" ) )
ENDIF

o := TBrowseDB( 6,11, 16 , 70 )

o:colorSpec := Colors()

o:gotopBlock    :={||repsets->( Top( Searcher ))}
o:gobottomBlock :={||repsets->( Bot( Searcher ))}
o:skipBlock     :={|n|repsets->( SkipIt( n, Searcher,bKey))}
bKey := COMPILE(repsets->( ordKey()) )
o:addColumn( TBColumnNEW( cRepName , {|| repsets->title } ) )

o:goTop()

DispBox( o:nTop-1, o:nLeft-1 , o:nBottom+1, o:nRight+1 , FRAMECAPTION +" ", "W+/B" )

WHILE .T.
    WHILE !o:stabilize()
      nKey := INKEY()
      IF nKey <> 0
         EXIT
      ENDIF
    ENDDO

    nKey := TimeOutInKey()


    IF nKey = K_ESC
       EXIT
    ELSEIF StdKeys( nKey , o )
    ELSEIF nKey == K_ENTER
       nKey := Directory( cRepName+"d.*" )
       IF Empty( nKey )
          Msg24( {"213"} , 3 , .T. )
          LOOP
       ENDIF

       prnRestoreData(cRepName+"d."+ Alltrim(repsets->repfile))
       GetList[1]:varPut( Padr( Alltrim(repsets->title),40) )   // from 70   29.03.00
       EXIT
    ELSEIF nKey = K_DEL
       IF ALERT("Are you sure you want to;delete this criteria ?",;
                     {"Yes","No"}, ALERT_STD) == 1
          cDelReport := Alltrim(repsets->repname) + "d." + Alltrim(repsets->repfile)
          IF repsets->( RecLock( 5,"",.F. ) )
             repsets->( DbDelete() )
             Ferase( cDelReport )
             repsets->( DbUnLock() )
          ENDIF
          o:goTop()
          o:refreshAll()
       ENDIF
    ENDIF
ENDDO
scrnPop()
IF LastKey() != K_ESC
   RedrawChecks()
ENDIF
NETCLOSE repsets
RETURN


STATIC PROCEDURE RedrawChecks( lCancel )
LOCAL nLen := Len( aCut ) , i
LOCAL nOffset := Ascan( GetList , {|oGet| "ACUTINDICATORS" $ Upper(oGet:name) } )

DEFAULT lCancel TO .F.
nOffset--
IF lCancel
   Afill( aCutIndicators , .F. )
ENDIF

FOR i:=1 TO nLen
    DrawCheck( Getlist[nOffset+i] )
    IF lCancel
       prnSetCritBuffer( aCut[i] , .T. )
    ENDIF
NEXT

RETURN


PROCEDURE prnRestoreData( cRepDosFileName,lDefault )
LOCAL cBuffer := MemoRead( cRepDosFileName )
LOCAL aLine , nPosition

DEFAULT lDefault  TO .f.



Afill( aCutIndicatiors , .F. )

WHILE !Empty( cBuffer )

      aLine := NextLine( @cBuffer )

      nPosition := Ascan( aCut , aLine[1] )   // crit name 1

      aCutIndicatiors[nPosition] := .T.
      IF ldefault .and. aLine[2]=="A" .AND. VALTYPE(aLine[3][1])=="D"
          aCutDefault[nPosition] := TRUE        // Add by s.b. to enable default
                                                // functions in date criteria
      ENDIF
      prnSetBuffer(aLine[3])                    // set the general buffer in prnCrit

      prnSetCritBuffer( aCut[nPosition], .F. )  // set the personal buffer of crit
//       DrawCheck( Getlist[nOffset+nPosition] )

ENDDO

RETURN

#define NL  Chr(10)+Chr(13)


STATIC FUNCTION NextLine( cBuffer )
LOCAL nPos
LOCAL cTemp , aTemp
LOCAL cCritName
LOCAL cType
LOCAL xValue


nPos := At( NL , cBuffer )
IF nPos > 0
   cTemp := Left( cBuffer , nPos-1 )
   cBuffer := SubStr( cBuffer , nPos+2 )
ELSE
   RETURN {} // end of crit ascii file so return an empty array indication for end
ENDIF

// set crit name
nPos := At( "=" , cTemp )
IF nPos > 0
   cCritName := Left( cTemp , nPos-1 )
   cTemp := SubStr( cTemp , nPos+1 )
ENDIF

// set type
nPos := At( "." , cTemp )
IF nPos > 0
   cType := Right( Left( cTemp , nPos-1 ),1 )
   cTemp := SubStr( cTemp , nPos+1 )
ENDIF

//
  //cTemp := StrTran( cTemp , "." , "" )   //s.b. took it off 09/05/97
DO CASE
   CASE cType == "C"
        xValue := cTemp
   CASE cType == "N"
        xValue := Val( cTemp )
   CASE cType == "D"

        xValue := Ctod( cTemp )

   CASE cType == "A"
        xValue := Turn2Arr( cTemp )
ENDCASE

RETURN  { cCritName, cType, xValue }

STATIC FUNCTION Turn2Arr( cTemp )
LOCAL nPos
LOCAL xValue1
LOCAL aValue := {}
LOCAL cType

WHILE !Empty( cTemp )

   nPos := At( "," , cTemp )

   IF nPos > 0
      xValue1 := SubStr( cTemp , 1, nPos-1 )
      Aadd( aValue , CreateVal( xValue1 ) )
      cTemp := SubStr( cTemp , nPos+1,Len(cTemp) - nPos - 1)
   ELSE
      IF !Empty( cTemp )
         Aadd( aValue , CreateVal( cTemp ) )
         cTemp := ""
      ENDIF
   ENDIF

ENDDO

RETURN aValue

STATIC FUNCTION CreateVal( xVal )
LOCAL cType := SubStr( xVal , 2 , 1 )
LOCAL xRetVal

DO CASE
   CASE cType == "C"
        xRetVal := SubStr( xVal , 4 )
   CASE cType == "N"
        xRetVal := Val( SubStr( xVal , 4 ) )
   CASE cType == "D"
        xRetVal := Ctod( SubStr( xVal , 4 ) )
   CASE cType == "F"
        xRetVal := SubStr( xVal , 4 )=="T"
ENDCASE

RETURN xRetVal


/*PROCEDURE prnCritPage( cIndexKey )
LOCAL cLastPage := "Selected order :" + cSortType + Chr(10) + Chr(13) +;
                    "Key :" + cIndexKey + Chr(10) + Chr(13) + Chr(10) + Chr(13)+;
                    Chr(10) + Chr(13) + Chr(10) + Chr(13) + Chr(10) + Chr(13)

cLastPage += "Criterions selected:" + Chr(10) + Chr(13)

cLastPage += BuildCritData( aCut , aCutIndicators , .F. )

? cLastPage
RETURN */

FUNCTION prnCritPage( cIndexKey )


LOCAL cLastPage

IF(cSortType == NIL, cSortType := "", NIL )

cLastPage := "Selected order :" + cSortType + NL  +;
                   "Key :" + cIndexKey + NL + NL + NL + NL + NL + NL

cLastPage += "Criterions selected:" + Chr(10) + Chr(13)

cLastPage += BuildCritData( aCut , aCutIndicators , .F. )
Set Console OFF
Set Print ON
? cLastPage
Set Print OFF
Set Console ON

RETURN NIL

/*
 * �� Function ��������������������������������������������������������������Ŀ
 * �         Name: prnShowCrits()        Docs: Shalom LeVine                  �
 * �  Description:                                                            �
 * �       Author: Shalom LeVine                                              �
 * � Date created: 06-08-97              Date updated: �06-08-97              �
 * � Time created: 12:44:19pm            Time updated: �12:44:19pm            �
 * �    Copyright: AVX                                                        �
 * ��������������������������������������������������������������������������Ĵ
 * �    Arguments: None                                                       �
 * � Return Value: NIL                                                        �
 * �     See Also:                                                            �
 * ����������������������������������������������������������������������������
 */
FUNCTION prnShowCrits()

LOCAL cScr   := SAVESCREEN()
LOCAL nRow   := 2
LOCAL aCrits := aPrnCritPage( NIL, TRUE )
LOCAL i
LOCAL cMemo  := ""
FOR i := 1 TO LEN( aCrits )
    cMemo += aCrits[i]
NEXT

@ 2, 0 CLEAR TO 23, 79
@24,0 SAY PADC("Arrow keys to scroll, F1 for Help, ESC to exit",80) COLOR "w+/r"
MEMOEDIT( cMemo, 2, 0, 23, 79, .F., NIL, 80 )
RESTSCREEN( 0, 0, 24, 79, cScr )

RETURN NIL


FUNCTION prnHelpCrits()
LOCAL cScr   := SAVESCREEN()
LOCAL cMemo  := ""
cMemo := memoread("HelpCrit.txt")
@ 2, 0 CLEAR TO 23, 79
@24,0 SAY PADC("Arrow keys to scroll, ESC to exit",80) COLOR "w+/r"
MEMOEDIT( cMemo, 2, 1, 23, 79, .F., NIL, 80 )
RESTSCREEN( 0, 0, 24, 79, cScr )

RETURN NIL

//****************************************************************
/*
FUNCTION Help()

LOCAL cScr   := SAVESCREEN()
LOCAL nRow   := 2
LOCAL aCrits := aPrnCritPage( NIL, TRUE )
LOCAL i
LOCAL cMemo  := ""
IF SELECT("help") == 0
     NetUse("help", STD_RETRY, RDD_IN_USE, USE_SHARED, USE_NEW, NIL )
ENDIF
help->( DBSETINDEX("progName"))
help->(DBSEEK(upper(procname(1))))
IF FOUND()
     cMemo := help->helpText
     @ 2, 0 CLEAR TO 23, 79
     @24,0 SAY PADC("Arrow keys to scroll, ESC to exit",80) COLOR "w+/r"
     MEMOEDIT( cMemo, 2, 1, 23, 79, .F., NIL, 80 )
ELSE

ENDIF
RESTSCREEN( 0, 0, 24, 79, cScr )

RETURN NIL
*/
/*
 * �� Function ��������������������������������������������������������������Ŀ
 * �         Name: aPrnCritPage()        Docs: Shalom LeVine                  �
 * �  Description:                                                            �
 * �       Author: Shalom LeVine                                              �
 * � Date created: 06-08-97              Date updated: �06-08-97              �
 * � Time created: 11:44:52am            Time updated: �11:44:52am            �
 * �    Copyright: AVX                                                        �
 * ��������������������������������������������������������������������������Ĵ
 * �    Arguments: cIndexKey                                                  �
 * �             : lShowOnScr                                                 �
 * � Return Value: aLines                                                     �
 * �     See Also:                                                            �
 * ����������������������������������������������������������������������������
 */
FUNCTION aPrnCritPage( cIndexKey, lShowOnScr )
// s.b. This function add by Shai to pass to the report class
// an array of crit that will be add to the summary of the report.

LOCAL i,nLen,aTemp,aLines := {}
LOCAL iSplit, nSplits

DEFAULT cIndexKey  TO ""
DEFAULT lShowOnScr TO FALSE

AADD(aLines, lJustify("Selected order :" + cSortType, 80 ) )
IF !lShowOnScr
  AADD(aLines,"Key :" + cIndexKey)
END
AADD(aLines, lJustify( "Criterions selected:", 80 ) )

aTemp := aBuildCritData( aCut , aCutIndicators , .F. )
nLen := LEN(aTemp)
FOR i:= 1 TO nLen
    IF lShowOnScr
       IF LEN( aTemp[i] ) > 80
          nSplits := MLCOUNT( aTemp[i], 58 )
          AADD( aLines, LJustify(MEMOLINE( aTemp[i], 58, 1 ), 80 ) )
          FOR iSplit := 2 TO nSplits
              AADD( aLines, SPACE(21)+":"+MEMOLINE( aTemp[i], 58, iSplit ) )
          NEXT
       ELSE
          AADD(aLines, LJustify( aTemp[i], 80 ) )
       ENDIF
    ELSE
      AADD(aLines,aTemp[i])
    END
NEXT

RETURN  aLines

/*
 * �� Function ��������������������������������������������������������������Ŀ
 * �         Name: prnGetUserMsg()       Docs: Shalom LeVine                  �
 * �  Description:                                                            �
 * �       Author: Shalom LeVine                                              �
 * � Date created: 08-24-97              Date updated: �08-24-97              �
 * � Time created: 12:31:01pm            Time updated: �12:31:01pm            �
 * �    Copyright: AVX                                                        �
 * ��������������������������������������������������������������������������Ĵ
 * � Return Value: cUserMsg                                                   �
 * �     See Also:                                                            �
 * ����������������������������������������������������������������������������
 */
FUNCTION prnGetUserMsg
default cUserMsg to Space( 35 )
RETURN cUserMsg + "  ** RESTRICTED **"

/*
 * �� Procedure �������������������������������������������������������������Ŀ
 * �         Name: TabGet                                                     �
 * �  Description:                                                            �
 * �       Author: Shalom LeVine         Designer: Dmitri Dain                �
 * � Date created: 08-24-97              Date updated: �08-24-97              �
 * � Time created: 12:31:38pm            Time updated: �12:31:38pm            �
 * �    Copyright: AVX                                                        �
 * ��������������������������������������������������������������������������Ĵ
 * �   Parameters: None                                                       �
 * �     See Also:                                                            �
 * ����������������������������������������������������������������������������
 */

PROCEDURE TabGet
LOCAL nLen := Len( GetList ) , nGetPos , i
LOCAL cGetName
LOCAL nDowns := 0

nGetPos := Ascan( GetList , {|o| o:hasFocus } )
cGetName := GetList[nGetPos]:name
i := nGetPos

WHILE .T.
   i++
   DO CASE
      CASE i > nLen
           KEYBOARD Chr( K_CTRL_HOME )
           GetList[nGetPos]:exitState := GE_TOP
           EXIT
      CASE GetList[i]:name == cGetName
           nDowns++
      CASE GetList[i]:name != cGetName
//           nDowns++
           KEYBOARD Replicate(Chr( K_DOWN ),nDowns)
           GetList[nGetPos]:exitState := GE_DOWN
           EXIT
   ENDCASE
ENDDO
RETURN
/*
Function GetPrnAttr( cPrinter )

local cPrintFile
LOCAL aRP := {}

IF( SET( _SET_EXCLUSIVE ) )
    USE (cPrintFile) INDE (cPrintFile) ALIAS ___xxx___ NEW SHARED
ELSE
    USE (cPrintFile) INDE (cPrintFile) ALIAS ___xxx___ NEW READONLY
ENDIF

IF( !neterr() .AND. dbSeek( upper( trim( cPrinter  ) ) ) )

    AADD(aRP, trim( ___xxx___->PR_SETUP ) )
    AADD(aRP, trim( ___xxx___->PR_RESET )
    AADD(aRP, trim( ___xxx___->PR_6LPI  )
    AADD(aRP, trim( ___xxx___->PR_8LPI  )
    AADD(aRP, trim( ___xxx___->PR_10CPI )
    AADD(aRP, trim( ___xxx___->PR_12CPI )
    AADD(aRP, trim( ___xxx___->PR_COMPR )
    AADD(aRP, trim( ___xxx___->PR_PORT  )
    AADD(aRP, trim( ___xxx___->PR_LAND  )

    cBoldOn        := trim( ___xxx___->PR_BDON  )
    cBoldOff       := trim( ___xxx___->PR_BDOFF )
    cItalOn        := trim( ___xxx___->PR_ITON  )
    cItalOff       := trim( ___xxx___->PR_ITOFF )
    cUnderOn       := trim( ___xxx___->PR_ULON  )
    cUnderOff      := trim( ___xxx___->PR_ULOFF )
ENDIF

RETURN aRP
*/