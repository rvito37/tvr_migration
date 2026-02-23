# Plan: Replace TVR with native Clipper report engine

## Context

BMS uses TVR (The Visual Reporter) to generate reports. The `TheReport:Print()` method calls a chain of TVR functions: `rpNew()` → `rpQuickLoad()` → `rpGenReport()` → `rpPageOut()`. The goal is to produce **identical output files** without ANY TVR function calls, compiled on **Clipper 5.3**.

Phase 1 (DONE): All 209 RH2 files converted to 8 DBF tables in `RPT_DBF/`.
Phase 2 (THIS PLAN): Replace TVR with native Clipper code that reads from DBF tables.

## Strategy

**Keep `THEREPO.PRG` structure intact** — the class, methods, and call flow stay the same. Replace only what's inside `Print()`:

Instead of calling `rpNew() → rpQuickLoad() → rpGenReport()`, we:
1. Load report definition from our DBF tables into a simple Clipper structure
2. Open the data DBF, apply query filter, iterate records
3. Evaluate field expressions, format values, build text lines
4. Output lines to file (identical text format to current TVR file output)

The key insight: TVR's `rpGenReport()` ultimately produces **text lines** (array of strings per page) sent to `rpPageOut()` which writes them to a file. We replicate that text output directly.

## What changes in THEREPO.PRG

Only the `Print()` method body changes. Instead of ~150 lines of TVR calls, it calls our new function:

```clipper
* OLD (TVR):
oRP := rpNew(4,2,24,79,120,31)
oRP := rpQuickLoad(@oRP, ::cRepFileName)
rpGenReport(oRP)

* NEW (our code):
GenReportFromDBF(::cRepFileName, ::cTempFileDir, ::nDest, ::aDbs, ;
                 ::aTstBlocks, ::aMyBuffer, Self)
```

All other methods (`EXEC`, `Query`, `SpreadSheet`, `V7Export`, `CreateCondDb`, `GetDestin`, `SetSort`, etc.) remain **UNCHANGED**.

`AddSummary()` currently uses TVR functions (`rpLinePlace`, `rpRFldNew`, `rpLFieldNew`). We rewrite it to directly append text lines to our output — much simpler since AddSummary just adds criteria/remark text at the end.

## Files to create

### 1. `RPTGEN.PRG` — Report generator engine (~400 lines)

Main entry point replacing `rpGenReport()`. Reads report definition from DBF, iterates data, formats output.

```
FUNCTION GenReportFromDBF(cRptFile, cTempDir, nDest, aDbs, aTstBlocks, aMyBuffer, oTheRep)
```

Core logic:
1. Extract RPT_ID from cRptFile (e.g. "RPQC01V1.RH2" → "RPQC01V1")
2. Open RPT_MAIN, find report settings (page length, margins, orientation, etc.)
3. Open RPT_FLD, load all field definitions for this report
4. Open RPT_LINE + RPT_LFLD, load line layout (which fields go where on each line)
5. Open RPT_DB, load database references
6. Open RPT_LVL, load group levels
7. Open RPT_SORT, load sort definitions
8. Open the data DBF (from aDbs[1] — already prepared by CreateCondDb)
9. Set up output file handle (same logic as current: cTempDir + GetPrintFile())
10. Loop through records:
    - Check query filter (ShaiCond)
    - Evaluate each field expression via macro `&(cExpr)`
    - Format values according to field type/length/decimals
    - Place values at correct columns (from RPT_LFLD COL_START/COL_END)
    - Handle group breaks (RPT_LVL): print headers/footers, reset totals
    - Handle page breaks: print page header/footer, form feed
    - Handle totals: accumulate SUM/COUNT/AVG/etc per level
11. Write summary section (criteria text from AddSummary)
12. Close output file

### 2. `RPTLOAD.PRG` — Report definition loader (~200 lines)

Loads report structure from our 8 DBF tables into simple Clipper arrays.

```
FUNCTION LoadReportDef(cRptId) -> aRptDef
```

Returns a simple structure:
```clipper
aRptDef[1] = cRptId
aRptDef[2] = aSettings  // from RPT_MAIN: page_len, margins, orientation, etc.
aRptDef[3] = aFields    // from RPT_FLD: array of {tbl, name, type, len, dec, expr, level, proc, tottyp}
aRptDef[4] = aLines     // from RPT_LINE: array of {type, level, row, filter, trim, color, newpg, height}
aRptDef[5] = aLFlds     // from RPT_LFLD: array of {line_idx, col_start, col_end, fld_idx, fmt, just, trim, dec}
aRptDef[6] = aDBs       // from RPT_DB: array of {table, alias, index, order, rdd}
aRptDef[7] = aRels      // from RPT_REL: array of {db_idx, from, to, expr, match, type}
aRptDef[8] = aSorts     // from RPT_SORT: array of {fld_idx, order}
aRptDef[9] = aLevels    // from RPT_LVL: array of {fld_idx, desc, break, pgreset, ...}
```

**No TVR constants, no oRP structure** — clean Clipper arrays.

### 3. `RPTFMT.PRG` — Field formatting utilities (~100 lines)

```
FUNCTION FmtField(xValue, cType, nLen, nDec, nJust) -> cFormatted
FUNCTION PlaceFields(cLine, aLFlds, aValues) -> cLine
FUNCTION MakeSeparator(nWidth, aLFlds) -> cLine  // builds "+---+---+" lines
```

## Files to modify

### `THEREPO.PRG` — Minimal changes

1. Remove TVR `#include "rp.ch"` / `#include "rptrans.ch"`
2. Remove TVR `#DEFINE` constants (lines 2-10) — replace with our own if needed
3. Rewrite `Print()` method body (~100 lines → ~40 lines calling GenReportFromDBF)
4. Rewrite `AddSummary()` to append text lines directly (no rpLinePlace/rpRFldNew)
5. Keep ALL other methods exactly as-is
6. `GetDestin()` — keep but use simple numeric constants (1=printer, 2=file, 3=display)

### What stays the same in THEREPO.PRG
- `init()` — unchanged
- `EXEC()` — unchanged (still calls prnFace, GetDestin, Print)
- `SetSort/SetDB/SetCrit/SetCheck/SetBuffer/SetQueryBlocks` — unchanged
- `CreateCondDb()` — unchanged (still creates temp filtered DBF)
- `IndexTempFile()` — unchanged
- `SpreadSheet()` — unchanged
- `V7Export()` — unchanged
- `Query()` — unchanged
- `GetDestin()` — unchanged (uses same constant values 1/2/3)

## TVR functions to eliminate

| TVR Function | What it does | Our replacement |
|---|---|---|
| `rpNew()` | Create empty oRP array | Not needed — we use our own structure |
| `rpQuickLoad()` | Load RH2 binary via getarray() | `LoadReportDef()` reads from DBF |
| `rpGenReport()` | Core report engine | `GenReportFromDBF()` our engine |
| `rpPageOut()` | Write page to file/printer | Direct `fwrite()` in our engine |
| `rpDataPath/rpIndexPath/rpSwapPath` | Set paths on oRP | Paths passed directly to our function |
| `rpUseFonts()` | Toggle PCL fonts | Not needed (we don't use fonts) |
| `rpGetRDO()` | Find database in oRP by alias | Not needed — we use aDbs directly |
| `rpDBTable/rpDBIndex/rpMyDBOpen` | Set/open database | Done in CreateCondDb already |
| `rpDBKeyTBlock()` | Set index key block | Done in CreateCondDb already |
| `rpDestination/rpPrinter/rpOutFile` | Set output target | Direct file open in our engine |
| `rpInitPcodes()` | Init printer escape codes | We write plain text (no escape codes for file output) |
| `rpKillSorts/rpCloseData` | Cleanup | Simple file close/delete |
| `rpQuerytBlock()` | Set query filter | Filter via ShaiCond() directly |
| `rpLinePlace/rpRFldNew/rpLFieldNew` | Dynamic line creation | Direct string building in AddSummary |
| `rpRebuildDisp()` | Rebuild display expressions | Not needed |

## DBF tables needed on Clipper machine

The 8 DBF files from `RPT_DBF/` must be accessible:
- `RPT_MAIN.DBF` — report headers (106 KB)
- `RPT_FLD.DBF` — field definitions (17 MB)
- `RPT_LINE.DBF` — line layout (922 KB)
- `RPT_LFLD.DBF` — field placements (1.3 MB)
- `RPT_DB.DBF` — database refs (49 KB)
- `RPT_REL.DBF` — relations (69 KB)
- `RPT_SORT.DBF` — sorts (361 B)
- `RPT_LVL.DBF` — group levels (108 KB)

Path will be configurable (e.g. `cRptDBFDir` variable or read from config).

## Output format

The output is a **text file** identical to what TVR produces:
- Fixed-width monospace columns (80 or 120 chars wide)
- Page headers/footers repeated each page
- Group headers/footers at level breaks
- Column values placed at exact positions (COL_START..COL_END)
- Form-feed character (chr(12)) between pages
- Totals/subtotals at group breaks and report end
- Summary (criteria) text appended at end (from AddSummary)

## Key files to reference

| File | What we need from it |
|---|---|
| `C:\Users\AVXUser\BMS\THEREPO.PRG` | Current Print() method — our modification target |
| `C:\Users\AVXUser\TVR\RP.CH` | oRP array structure (indices, constants) — reference for DBF mapping |
| `C:\Users\AVXUser\TVR\RPTRANS.CH` | #xtranslate macros — shows how TVR get/set functions work |
| `C:\Users\AVXUser\TVR\SOURCE\RP2\RP\RPNEW.PRG` | rpNew() — default initialization values |
| `C:\Users\AVXUser\TVR\SOURCE\RP2\RLO\LPLACEL.PRG` | rpLinePlace() — line insertion logic |
| `C:\Users\AVXUser\TVR\SOURCE\RP2\LFO\FLDNEW.PRG` | rpLFieldNew() — field placement logic |
| `C:\Users\AVXUser\TVR\SOURCE\RP2\RFO\RFLDNEW.PRG` | rpRFldNew() — field creation logic |
| `C:\Users\AVXUser\TVR\SOURCE\RP2\RDO\GETRDO.PRG` | rpGetRDO() — alias lookup |
| `C:\Users\AVXUser\BMS\RPSAVE.PRG` | rpQuickLoad() — what we're replacing |
| `C:\Users\AVXUser\BMS\GEN.PRG` | rpGenReport() — the engine we're reimplementing |
| `C:\Users\AVXUser\BMS\PAGEOUT.PRG` | rpPageOut() — output writing |
| `C:\Users\AVXUser\BMS\RUNINIT.PRG` | rpRunInit() — runtime setup |
| `C:\Users\AVXUser\BMS_RH2_temp\source_prg\RH2TODBF.PRG` | Our DBF schema definitions |

## Implementation order

1. Write `RPTLOAD.PRG` — load report def from DBF (testable standalone)
2. Write `RPTFMT.PRG` — field formatting (testable standalone)
3. Write `RPTGEN.PRG` — report engine (the big one)
4. Modify `THEREPO.PRG` — rewire Print() and AddSummary()
5. Test: compare output of one report (RPQC01V1) with TVR output
6. Test: run full BMS Print flow end-to-end

## Verification

1. Run a report via old TVR path → capture text file output
2. Run same report via new path → capture text file output
3. Diff the two files — should be character-for-character identical
4. Test with multiple report types (simple, grouped, with totals, with summary)
5. Compile entire chain on Clipper 5.3
