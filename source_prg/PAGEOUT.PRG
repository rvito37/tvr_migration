//#include "rp.ch"
#include "rptrans.ch"
#define FALSE .F.
#define TRUE .T.

static lPCodesSent  := FALSE
static nDiskFree    := NIL

/*========================================================================*/
FUNC rpPageOut( oRP , aPage )
local nK    := 0
local nLen  := len( aPage )
local cStr  := ""
local nTmp  := 0
local lTmp  := TRUE
local lNew  := FALSE
local nPort := CASE( { upper( oRP[ rpREPORT ][ rpREPORT_OUT_PORT ] ), ;
                       "LPT1", 1, ;
                       "LPT2", 2, ;
                       "LPT3", 3, ;
                       "PRN" , 1, 1 } )

local lUserFlag := IIF( valtype( oRP[ rpUSERFUNCS ][ rpUSER_LINE_OUT_BLOCK ] ) EQ "B" , TRUE, FALSE )

/* if we haven't reached the first page yet or are past the last page
----------------------------------------------------------------------*/
IF( ( rpPageNo( oRP ) GT 0 AND rpPageNo( oRP ) LT rpStartPage( oRP ) ) OR rpPageNo( oRP ) GT rpEndPage( oRP ) )
    return( NIL )
ENDIF

/* do they want out?
---------------------*/
IF( rpCheckTerminate( oRP ) OR lUserFlag )
    return( NIL )
ENDIF

/* HTML output - if HtmlIsOpen() we redirect all page output to HTML
   file and skip the normal printer/file logic
---------------------------------------------------------------------*/
IF HtmlIsOpen()
   HtmlPageOut( aPage )
   return( NIL )
ENDIF

DO CASE

   CASE( rpDestination( oRP ) EQ rpPRINTER )

         /* send printer codes
         ----------------------*/
         IF( !lPCodesSent )

             #IFDEF _FONTS_
				 IF( !rpUseFonts( oRP ) )
             #ENDIF
                 rpLPrint( oRP[ rpRUNTIME ][ rpRUNTIME_CODES ][ 1 ][ 2 ], nPort )
                 rpLPrint( oRP[ rpRUNTIME ][ rpRUNTIME_CODES ][ 1 ][ 1 ], nPort )
                 inkey(.5)
                 IF( oRP[ rpREPORT ][ rpREPORT_PAGE_ORIENT ] EQ 2 )
                     rpLPrint( oRP[ rpRUNTIME ][ rpRUNTIME_CODES ][ 1 ][ 9 ], nPort )
                 ELSE
                     rpLPrint( oRP[ rpRUNTIME ][ rpRUNTIME_CODES ][ 1 ][ 8 ], nPort )
                 ENDIF
                 inkey(1)
                 nTmp := CASE( { oRP[ rpREPORT ][ rpREPORT_CHARS_PER_INCH ], 10, 1, 12, 2, 3 } )
                 rpLPrint( oRP[ rpRUNTIME ][ rpRUNTIME_CODES ][ 1 ][ 4 + nTmp ], nPort )
                     inkey(.5)
                 IF( oRP[ rpREPORT ][ rpREPORT_LINES_PER_INCH ] EQ 8 )
                     rpLPrint( oRP[ rpRUNTIME ][ rpRUNTIME_CODES ][ 1 ][ 4 ], nPort )
                 ELSE
                     rpLPrint( oRP[ rpRUNTIME ][ rpRUNTIME_CODES ][ 1 ][ 3 ], nPort  )
                 ENDIF
                 inkey(1)

             #IFDEF _FONTS_
				 ENDIF
             #ENDIF

             #IFDEF _FONTS_
				 IF( rpUseFonts( oRP ) )
             	  IF( !empty( rpGetInitCodes( oRP ) ) )
		               rpLPrint( rpGetInitCodes( oRP ) )
		               inkey(1)
	              ENDIF
	          ENDIF
             #ENDIF

             lPCodesSent := TRUE
         ENDIF

         IF( pError() GT 0 OR !isprinter() )
             DO WHILE( TRUE )

                IF( !isprinter() )
                    IF( rpMessage( oRP, rpMESSAGE_PRINTER_FAIL ) )
                        LOOP
                    ELSE
                        rpError( oRP , rpERROR_TIMEOUT )
                        return( NIL )
                    ENDIF
                ELSE
                    EXIT
                ENDIF
             ENDDO
         ENDIF

         DO WHILE( ++nK LE nLen )

             IF( at( chr( 12 ), aPage[ nK ] ) GT 0 )

					  // OUT OUT 3-06-96
					  //#IFDEF _FONTS_

					  IF( rpUseFonts( oRP ) )
                 		//rpLPrint( chrswap( aPage[ nK ], chr(12), "" ), nPort )
                 		//rpLPrint( chrswap( aPage[ nK ], chr(12), "" ) + chr(13), nPort )
                 		rpLPrint( aPage[ nK ] + chr(13), nPort )
                 		inkey(1)
					  ELSE
                 		rpLPrint( aPage[ nK ] + chr(13), nPort )
                 		inkey(1)
					  ENDIF

                 IF( nK GE nLen )
                     EXIT
                 ENDIF


             ELSE
					  IF( rpUseFonts( oRP ) )
                         rpLPrint( aPage[ nK ] + chr(13) + chr(10), nPort )
					  ELSE
                 		rpLPrintline( aPage[ nK ], nPort )
					  ENDIF
             ENDIF

             IF( rpCheckExitKey( oRP ) )
                 EXIT
             ENDIF

             IF( pError() GT 0 ) //OR !isprinter() )
                 DO WHILE( TRUE )
                    IF( !isprinter() )
                        IF( rpMessage( oRP, rpMESSAGE_PRINTER_FAIL ) )
                            LOOP
                        ELSE
                            rpError( oRP , rpERROR_TIMEOUT )
                            return( NIL )
                        ENDIF
                    ELSE
                        EXIT
                    ENDIF
                 ENDDO
                 IF( rpMessage( oRP, rpMESSAGE_REPRINT_PAGE ) )

                     #IFDEF _FONTS_
                         rpPageNew()
                         rpJobFlush()
                     #ELSE
                         rpLPrint( chr(12), nPort )
                     #ENDIF

                     inkey(2)
                     nK := 0
                     LOOP
                 ENDIF

             ENDIF
         ENDDO

   CASE( oRP[ rpREPORT ][ rpREPORT_HANDLE ] GT 0 )

         IF( nDiskFree EQ NIL )

				 // OUT OUT 1-15-96
				 //cStr := fparsedr( oRP[ rpREPORT ][ rpREPORT_NAME ] )

				 // NEW NEW 1-15-96
             cStr := fparsedr( oRP[ rpREPORT ][ rpREPORT_OUTFILE ] )
             IF( empty( cStr ) )

				 	  // OUT OUT 1-15-96
					  //cStr := fparsedr( rpSwapPath( oRP ) )

				 	  // NEW NEW 1-15-96
                 cStr := curdrive()

             ENDIF
             nDiskFree := diskspace(cStr)

         ENDIF

         IF( nDiskFree LT ( 1024 * 10 ) )
             rpError( oRP, rpERROR_WRITE )
             return( NIL )
         ENDIF

         IF( !lPCodesSent )

         #IFDEF _FONTS_
			IF( !rpUseFonts( oRP ) )
         #ENDIF

             fwrite( oRP[ rpREPORT ][ rpREPORT_HANDLE ], oRP[ rpRUNTIME ][ rpRUNTIME_CODES ][ 1 ][ 2 ] , len( oRP[ rpRUNTIME ][ rpRUNTIME_CODES ][ 1 ][ 2 ] ) )
             fwrite( oRP[ rpREPORT ][ rpREPORT_HANDLE ], oRP[ rpRUNTIME ][ rpRUNTIME_CODES ][ 1 ][ 1 ] , len( oRP[ rpRUNTIME ][ rpRUNTIME_CODES ][ 1 ][ 1 ] ) )
             IF( oRP[ rpREPORT ][ rpREPORT_PAGE_ORIENT ] EQ 2 )
                 fwrite( oRP[ rpREPORT ][ rpREPORT_HANDLE ], oRP[ rpRUNTIME ][ rpRUNTIME_CODES ][ 1 ][ 9 ]  , len( oRP[ rpRUNTIME ][ rpRUNTIME_CODES ][ 1 ][ 9 ] ) )
             ELSE
                 fwrite( oRP[ rpREPORT ][ rpREPORT_HANDLE ], oRP[ rpRUNTIME ][ rpRUNTIME_CODES ][ 1 ][ 8 ]  , len( oRP[ rpRUNTIME ][ rpRUNTIME_CODES ][ 1 ][ 8 ] ) )
             ENDIF
             nTmp := CASE( { oRP[ rpREPORT ][ rpREPORT_CHARS_PER_INCH ], 10, 1, 12, 2, 3 } )
             fwrite( oRP[ rpREPORT ][ rpREPORT_HANDLE ], oRP[ rpRUNTIME ][ rpRUNTIME_CODES ][ 1 ][ 4 + nTmp ], len( oRP[ rpRUNTIME ][ rpRUNTIME_CODES ][ 1 ][ 4 + nTmp ] ) )
             IF( oRP[ rpREPORT ][ rpREPORT_LINES_PER_INCH ] EQ 8 )
                 fwrite( oRP[ rpREPORT ][ rpREPORT_HANDLE ], oRP[ rpRUNTIME ][ rpRUNTIME_CODES ][ 1 ][ 4 ] , len( oRP[ rpRUNTIME ][ rpRUNTIME_CODES ][ 1 ][ 4 ] ) )
             ELSE
                 fwrite( oRP[ rpREPORT ][ rpREPORT_HANDLE ], oRP[ rpRUNTIME ][ rpRUNTIME_CODES ][ 1 ][ 3 ] , len( oRP[ rpRUNTIME ][ rpRUNTIME_CODES ][ 1 ][ 3 ] ) )
             ENDIF
             lPCodesSent := TRUE

             #IFDEF _FONTS_
				 ENDIF
             #ENDIF

             #IFDEF _FONTS_
				 IF( rpUseFonts( oRP ) )
             	  IF( !empty( rpGetInitCodes( oRP ) ) )
		               rpLPrint( rpGetInitCodes( oRP ) )
		               inkey(1)
	              ENDIF
	          ENDIF
             #ENDIF


         ENDIF


         FOR nK := 1 to nLen

             lNew := FALSE

             IF( at( chr( 12 ), aPage[ nK ] ) GT 0 )
                 IF( rpPrinter( oRP ) EQ "ASCII" )
                     aPage[ nK ]:= chrswap( aPage[ nK ], chr(12), "") +chr(13)+chr(10)
                 ELSE
                     aPage[ nK ] += (chr(13))
                 ENDIF
                 fwrite( oRP[ rpREPORT ][ rpREPORT_HANDLE ], trim( aPage[ nK ] ) )
                 LOOP
             ENDIF

             IF( !fwriteline( oRP[ rpREPORT ][ rpREPORT_HANDLE ], trim( aPage[ nK ] ) ) )
                 nDiskFree -= len( trim( aPage[ nK ] ) )
                 IF( nDiskFree LT 15000 )
                     rpError( oRP, rpERROR_WRITE )
                     return( NIL )
                 ENDIF
             ENDIF
             IF( fError() GT 0 )
                 rpError( oRP, rpERROR_WRITE )
                 return( NIL )
             ENDIF
         NEXT
ENDCASE

return( NIL )
/*========================================================================*/

/*========================================================================*/
FUNC rpPrintReset( oRP )
local nPort := CASE( { upper( oRP[ rpREPORT ][ rpREPORT_OUT_PORT ] ), ;
                       "LPT1", 1, ;
                       "LPT2", 2, ;
                       "LPT3", 3, ;
                       "PRN" , 1, 1 } )

lPCodesSent := FALSE

/* HTML - close the html file before anything else
---------------------------------------------------*/
IF HtmlIsOpen()
   HtmlClose()
   return( NIL )
ENDIF

IF( rpDestination( oRP ) EQ rpPRINTER )
    rpLPrint( oRP[ rpRUNTIME ][ rpRUNTIME_CODES ][ 1 ][ 2 ], nPort )
ELSEIF( oRP[ rpREPORT ][ rpREPORT_HANDLE ] GT 0 )
    fwrite( oRP[ rpREPORT ][ rpREPORT_HANDLE ], oRP[ rpRUNTIME ][ rpRUNTIME_CODES ][ 1 ][ 2 ], len( oRP[ rpRUNTIME ][ rpRUNTIME_CODES ][ 1 ][ 2 ] ) )
ENDIF

return( NIL )
/*========================================================================*/

