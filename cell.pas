(*
** Module   :CELL
** Abstract :Cell Toolkit
**
** Copyright (C) Sergey I. Yevtushenko
** Log: Sun  08/02/98   Created
**      Wed  25/10/2000 Updated to version 0.7b
*)
unit cell;
interface
{$Z-,P-,S-,R-,B-}
uses os2def, os2pmapi;

(* Constants *)

const TK_VERSION      ='0.7b';  (* Toolkit version *)
      CELL_WINDOW     = $0000;  (* Cell is window *)
      CELL_VSPLIT     = $0001;  (* Cell is vertically splitted view *)
      CELL_HSPLIT     = $0002;  (* Cell is horizontally splitted view *)
      CELL_SPLITBAR   = $0004;  (* Call has a splitbar *)
      CELL_FIXED      = $0008;  (* Views can't be sized *)
      CELL_SIZE1      = $0010;  (* *)
      CELL_SIZE2      = $0020;
      CELL_HIDE_1     = $0040;  (* Cell 1 is hidden *)
      CELL_HIDE_2     = $0080;  (* Cell 2 is hidden *)
      CELL_HIDE       = $00C0;  (* Cell 1 or cell 2 is hidden *)
      CELL_SPLIT_MASK = $003F;
      CELL_SWAP       = $1000;  (* Cells are swapped *)
      CELL_SPLIT10x90 = $0100;  (* Sizes of panels related as 10% and 90% *)
      CELL_SPLIT20x80 = $0200;  (* Sizes of panels related as 20% and 80% *)
      CELL_SPLIT30x70 = $0300;  (* Sizes of panels related as 30% and 70% *)
      CELL_SPLIT40x60 = $0400;  (* Sizes of panels related as 40% and 60% *)
      CELL_SPLIT50x50 = $0500;  (* Sizes of panels related as 50% and 50% *)
      CELL_SPLIT60x40 = $0600;  (* Sizes of panels related as 60% and 40% *)
      CELL_SPLIT70x30 = $0700;  (* Sizes of panels related as 70% and 30% *)
      CELL_SPLIT80x20 = $0800;  (* Sizes of panels related as 80% and 20% *)
      CELL_SPLIT90x10 = $0900;  (* Sizes of panels related as 90% and 10% *)
      CELL_SPLIT_REL  = $0F00;

      TB_BUBBLE       = $0001; (* Toolbar has bubble help *)
      TB_VERTICAL     = $0002; (* Default toolbar view is vertical *)
      TB_FLOATING     = $0004; (* Toolbar not attached *)
      TB_ATTACHED_LT  = $0010; (* Toolbar attached to left side  *)
      TB_ATTACHED_TP  = $0020; (* Toolbar attached to right side *)
      TB_ATTACHED_RT  = $0040; (* Toolbar attached to top side   *)
      TB_ATTACHED_BT  = $0080; (* Toolbar attached to bottom     *)
      TB_ALLOWED      = $00FF; (* *)

      TB_SEPARATOR    = $7001; (* Separator Item ID *)
      TB_BUBBLEID     = $7002; (* Bubble help window ID *)

(* Limits *)

      SPLITBAR_WIDTH   =    2; (* wodth of split bar between cells *)
      HAND_SIZE        =    8; (* toolbar drag 'hand' *)
      TB_SEP_SIZE      =    7; (* width of toolbar separator item *)
      TB_BUBBLE_SIZE   =   32; (* bubble help item size *)
      CELL_TOP_LIMIT   =   98; (* maximal space occupied by one cell (%%) *)
      CELL_BOTTOM_LIMIT=    2; (* minimal space occupied by one cell (%%) *)

(* Window classes *)

type PCellDef = ^CellDef;
     CellDef  = record
       lType    :longint; // Cell type flags
       pszClass :pchar;   // if flag CELL_WINDOW is set, this is a Window Class
       pszName  :pchar;   // Caption
       ulStyle  :longint; // if flag CELL_WINDOW is not set, this a Frame creation flags
       ulID     :longint; // Cell window ID
       pPanel1  :PCellDef;
       pPanel2  :PCellDef;
       pClassProc:FnWp;
       pClientClassProc:FnWp;
       lSize    :longint; // Meaningful only if both CELL_SIZE(1|2) and CELL_FIXED is set
     end;

     TbDef    = record
       lType    :longint; // Toolbar flags
       ulID     :longint; // Toolbar window ID
       tbItems  :plong;
     end;

(*
** Internal cell data, used by ordinary windows.
** May be useful for user-defined windows
*)
     PWindowCellCtlData = ^WindowCellCtlData;
     WindowCellCtlData  = record
       pOldProc :FnWp;
     end;


(* Prototypes *)

Procedure ToolkitInit(appAnchor:HAB);

Function  CreateCell(var pCell:CellDef; hWndParent,hWndOwner:HWND):HWND;
Function  CellWindowFromID(hwndCell:HWND; ulID:longint):HWND;
Function  CellParentWindowFromID(hwndCell:HWND; ulID:longint):HWND;
Procedure CreateToolbar(hwndCell:HWND; var pTb:TbDef);
Procedure GenResIDStr(buff:pchar; ulID:longint);

(* Some useful additions *)

Function  GetSplit(Window:HWND; lID:longint):longint;
Function  SetSplit(Window:HWND; lID,lNewSplit:longint):longint;
Procedure SetSplitType(Window:HWND; lID,lNewSplit:longint);
Function  GetSplitType(Window:HWND; lID:longint):longint;
Procedure ShowCell(Window:HWND; lID:longint; Action:boolean);

implementation
uses strings;

const TKM_SEARCH_ID       =WM_USER+$1000;
      TKM_QUERY_FLAGS     =WM_USER+$1001;
      TKM_SEARCH_PARENT   =WM_USER+$1002;

      TB_ATTACHED         =$00F8;

(*****************************************************************************
** Static data
*)
      CELL_CLIENT:pchar   ='Uni.Cell.Client';
      TB_CLIENT  :pchar   ='Uni.Tb.Client';
      TB_SEPCLASS:pchar   ='Uni.Tb.Separator';
      ppFont     :pchar   ='9.WarpSans';

(* Color tables *)

type  ClTableArray  = array [0..SPLITBAR_WIDTH-1] of longint;
      PClTableArray = ^ClTableArray;

const lColor     :ClTableArray=(
                    CLR_BLACK,
                    // CLR_PALEGRAY, { if (SPLITBAR_WIDTH>2) }
                    CLR_WHITE
                  );
      lColor2    :ClTableArray=(
                    CLR_WHITE,
                    // CLR_PALEGRAY, { if (SPLITBAR_WIDTH>2) }
                    CLR_BLACK
                  );

(*****************************************************************************
** Internal prototypes
*)
function  CellProc(Window: HWnd; Msg: ULong; Mp1,Mp2: MParam): MResult; cdecl; forward;
function  CellClientProc(Window: HWnd; Msg: ULong; Mp1,Mp2: MParam): MResult; cdecl; forward;
function  TbProc(Window: HWnd; Msg: ULong; Mp1,Mp2: MParam): MResult; cdecl; forward;
function  TbClientProc(Window: HWnd; Msg: ULong; Mp1,Mp2: MParam): MResult; cdecl; forward;
function  TbSeparatorProc(Window: HWnd; Msg: ULong; Mp1,Mp2: MParam): MResult; cdecl; forward;
function  BtProc(Window: HWnd; Msg: ULong; Mp1,Mp2: MParam): MResult; cdecl; forward;

function  CreateTb(var pTb:TbDef; hWndParent, hWndOwner:HWND):HWND; forward;
procedure RecalcTbDimensions(Window:HWND; pSize:PPOINTL); forward;
function  TrackRectangle(hwndBase:HWND; var rclTrack:RECTL; rclBounds:PRECTL):LONG; forward;

(*****************************************************************************
** Internal data types
*)

    (* Cell data, used by subclass proc of splitted window. *)

type PCellTb = ^CellTb;
     CellTb  = record
       Window:HWND;
       pNext :PCellTb;
     end;

     PCellCtlData = ^CellCtlData;
     CellCtlData  = record
       pOldProc:FNWP;
       rclBnd  :RECTL;
       lType   :longint;
       lSplit  :longint;
       lSize   :longint;
       hwndSplitbar :HWND;
       hwndPanel1   :HWND;
       hwndPanel2   :HWND;
       CellTbD      :PCellTb;
     end;


     (* Toolbar data *)

     PTbItemData = ^TbItemData;
     TbItemData  = record
       pOldProc:FNWP;
       cText   :array [0..TB_BUBBLE_SIZE-1] of char;
     end;

     PTbCtlData = ^TbCtlData;
     TbCtlData  = record
       pOldProc  :FNWP;
       hwndParent:HWND;
       lState    :longint;
       lCount    :longint;

       bBubble   :longbool;
       hwndBubble:HWND;
       hwndLast  :HWND;
       hItems    :array [0..0] of HWND;
     end;

var Anchor:HAB;

(* Function: ToolkitInit
** Abstract: Registers classes needed for toolkit
*)

Procedure ToolkitInit(appAnchor:HAB);
begin
  Anchor:=appAnchor;
  WinRegisterClass(Anchor, CELL_CLIENT, CellClientProc,  CS_SIZEREDRAW, sizeof(ULONG));
  WinRegisterClass(Anchor, TB_CLIENT,   TbClientProc,    CS_SIZEREDRAW, sizeof(ULONG));
  WinRegisterClass(Anchor, TB_SEPCLASS, TbSeparatorProc, CS_SIZEREDRAW, sizeof(ULONG));
end;

(*
******************************************************************************
** Cell (Splitted view) implementation
******************************************************************************
*)

Procedure ShowCell(Window:HWND; lID:longint; Action:boolean);
var hwndMain:HWND;
    pCtlData:PCellCtlData;
    lCell   :longint;
begin
  hwndMain:=Window;
  pCtlData:=nil;
  lCell   :=0;

  Window:=CellParentWindowFromID(Window,lID);
  if Window=0 then exit;

  pCtlData:=PCellCtlData(WinQueryWindowULong(Window,QWL_USER));
  if pCtlData=nil then exit;

  if WinQueryWindowUShort(pCtlData^.hwndPanel1,QWS_ID)=lID then lCell:=CELL_HIDE_1;
  if WinQueryWindowUShort(pCtlData^.hwndPanel2,QWS_ID)=lID then lCell:=CELL_HIDE_2;

  case lCell of
    CELL_HIDE_1:
      if Action then
        pCtlData^.lType:=pCtlData^.lType and not CELL_HIDE_1
      else
        pCtlData^.lType:=pCtlData^.lType or CELL_HIDE_1;
    CELL_HIDE_2:
      if Action then
        pCtlData^.lType:=pCtlData^.lType and not CELL_HIDE_2
      else
        pCtlData^.lType:=pCtlData^.lType or CELL_HIDE_2;
  end;

  if lCell<>0 then WinSendMsg(Window,WM_UPDATEFRAME,0,0);
end;

Function GetSplit(Window:HWND; lID:longint):longint;
var pCtlData:PCellCtlData;
begin
  pCtlData:=nil;
  result:=0;

  Window:=CellWindowFromID(Window,lID);
  if Window=0 then exit;

  pCtlData:=PCellCtlData(WinQueryWindowULong(Window,QWL_USER));
  if pCtlData=nil then exit;

  result:=pCtlData^.lSplit;
end;

Function SetSplit(Window:HWND; lID,lNewSplit:longint):longint;
var pCtlData:PCellCtlData;
begin
  pCtlData:=nil;
  result:=0;

  Window:=CellWindowFromID(Window,lID);
  if Window=0 then exit;

  pCtlData:=PCellCtlData(WinQueryWindowULong(Window,QWL_USER));
  if pCtlData=nil then exit;

  if pCtlData^.lType and CELL_FIXED=0 then
  begin
    pCtlData^.lSplit:=lNewSplit;
    if pCtlData^.lSplit>CELL_TOP_LIMIT then pCtlData^.lSplit:=CELL_TOP_LIMIT;
    if pCtlData^.lSplit<CELL_BOTTOM_LIMIT then pCtlData^.lSplit:=CELL_BOTTOM_LIMIT;

    WinSendMsg(Window,WM_UPDATEFRAME,0,0);
  end;
  result:=pCtlData^.lSplit;
end;

Function  GetSplitType(Window:HWND; lID:longint):longint;
var pCtlData:PCellCtlData;
begin
  pCtlData:=nil;
  result:=0;

  Window:=CellWindowFromID(Window,lID);
  if Window=0 then exit;

  pCtlData:=PCellCtlData(WinQueryWindowULong(Window,QWL_USER));
  if pCtlData=nil then exit;

  result:=pCtlData^.lType and (CELL_VSPLIT or CELL_HSPLIT or CELL_SWAP);
end;

Procedure SetSplitType(Window:HWND; lID,lNewSplit:longint);
var pCtlData:PCellCtlData;
    hwndTmp :HWND;
begin
  pCtlData:=nil;

  Window:=CellWindowFromID(Window,lID);
  if Window=0 then exit;

  pCtlData:=PCellCtlData(WinQueryWindowULong(Window,QWL_USER));
  if pCtlData=nil then exit;

  pCtlData^.lType:=pCtlData^.lType and not (CELL_VSPLIT or CELL_HSPLIT);
  pCtlData^.lType:=pCtlData^.lType or lNewSplit and (CELL_VSPLIT or CELL_HSPLIT);

  if lNewSplit and CELL_SWAP<>0 then //Swap required?
  begin
    if pCtlData^.lType and CELL_SWAP =0 then //Not swapped yet
    begin
      //Swap subwindows
      hwndTmp:=pCtlData^.hwndPanel1;
      pCtlData^.hwndPanel1:=pCtlData^.hwndPanel2;
      pCtlData^.hwndPanel2:=hwndTmp;
    end;
    pCtlData^.lType:=pCtlData^.lType or CELL_SWAP;
  end else
  begin
    if pCtlData^.lType and CELL_SWAP<>0 then //Already swapped
    begin
      // Restore original state
      hwndTmp:=pCtlData^.hwndPanel1;
      pCtlData^.hwndPanel1:=pCtlData^.hwndPanel2;
      pCtlData^.hwndPanel2:=hwndTmp;
    end;
    pCtlData^.lType:=pCtlData^.lType and not CELL_SWAP;
  end;
end;

(* Function: CountControls
** Abstract: calculates number of additional controls in cell window
*)

function CountControls(pCtlData:PCellCtlData):smallword;
var itemCount:smallword;
    CellTbD  :PCellTb;
    lFlags   :longint;
begin
  itemCount:=0;
  CellTbD  :=nil;

  if (pCtlData^.hwndPanel1<>0) and (pCtlData^.lType and CELL_HIDE_1=0)
    then inc(itemCount);
  if (pCtlData^.hwndPanel2<>0) and (pCtlData^.lType and CELL_HIDE_2=0)
    then inc(itemCount);

  CellTbD:=pCtlData^.CellTbD;

  while CellTbD<>nil do
  begin
    lFlags:=WinSendMsg(CellTbD^.Window,TKM_QUERY_FLAGS,0,0);
    if lFlags and TB_ATTACHED<>0 then inc(itemCount);
    CellTbD:=CellTbD^.pNext;
  end;
  result:=itemCount;
end;

(* Function: CreateCell
** Abstract: Creates a subwindows tree for a given CellDef
** Note: If hWndOwner == NULLHANDLE, and first CellDef is frame,
**       all subwindows will have this frame window as Owner.
*)

Function CreateCell(var pCell:CellDef; hWndParent,hWndOwner:HWND):HWND;
var hwndFrame:HWND;
    pCtlData :PCellCtlData;
    pWCtlData:PWindowCellCtlData;
begin
  hwndFrame:=NULLHANDLE;
  pCtlData :=nil;
  pWCtlData:=nil;
  result   :=NULLHANDLE;

  case pCell.lType and (CELL_VSPLIT or CELL_HSPLIT or CELL_WINDOW) of
    CELL_WINDOW:begin
        hwndFrame:=WinCreateWindow(hWndParent, pCell.pszClass, pCell.pszName,
          pCell.ulStyle, 0, 0, 0, 0, hWndOwner, HWND_TOP, pCell.ulID, nil, nil);

        if (@pCell.pClassProc<>nil) and (hwndFrame<>0) then
        begin
          new(pWCtlData);
          if pWCtlData=nil then begin result:=hwndFrame; exit end;

          fillchar(pWCtlData^,sizeof(WindowCellCtlData),#0);

          @pWCtlData^.pOldProc:=WinSubclassWindow(hwndFrame,pCell.pClassProc);
          WinSetWindowULong(hwndFrame,QWL_USER,ULONG(pWCtlData));
        end;
      end;
    CELL_HSPLIT, CELL_VSPLIT:begin
        new(pCtlData);
        if pCtlData=nil then begin result:=hwndFrame; exit end;

        fillchar(pCtlData^,sizeof(CellCtlData),#0);

        pCtlData^.lType:=pCell.lType and (CELL_SPLIT_MASK or CELL_HIDE);
        if pCell.lType and (CELL_SIZE1 or CELL_SIZE2 or CELL_FIXED)<>0 then
          pCtlData^.lSize:=pCell.lSize;
        pCtlData^.lSplit:=50;

        case pCell.lType and CELL_SPLIT_REL of
          CELL_SPLIT10x90: pCtlData^.lSplit:=10;
          CELL_SPLIT20x80: pCtlData^.lSplit:=20;
          CELL_SPLIT30x70: pCtlData^.lSplit:=30;
          CELL_SPLIT40x60: pCtlData^.lSplit:=40;
          CELL_SPLIT50x50: pCtlData^.lSplit:=50;
          CELL_SPLIT60x40: pCtlData^.lSplit:=60;
          CELL_SPLIT70x30: pCtlData^.lSplit:=70;
          CELL_SPLIT80x20: pCtlData^.lSplit:=80;
          CELL_SPLIT90x10: pCtlData^.lSplit:=90;
        end;

        hwndFrame:=WinCreateStdWindow(hWndParent, WS_VISIBLE, pCell.ulStyle,
          CELL_CLIENT, '', 0, 0, pCell.ulID, @pCtlData^.hwndSplitbar);

        WinSetOwner(hwndFrame,hWndOwner);

        if @pCell.pClassProc<>nil then
          @pCtlData^.pOldProc:=WinSubclassWindow(hwndFrame,pCell.pClassProc)
        else
          @pCtlData^.pOldProc:=WinSubclassWindow(hwndFrame,CellProc);

        if @pCell.pClientClassProc<>nil then
        begin
          new(pWCtlData);
          if pWCtlData=nil then begin result:=hwndFrame; exit end;

          fillchar(pWCtlData^,sizeof(WindowCellCtlData),#0);

          @pWCtlData^.pOldProc:=WinSubclassWindow(pCtlData^.hwndSplitbar,
            pCell.pClientClassProc);

          WinSetWindowULong(pCtlData^.hwndSplitbar,QWL_USER,ULONG(pWCtlData));
        end;

        if hWndOwner=0 then hWndOwner:=hwndFrame
          else WinSetOwner(pCtlData^.hwndSplitbar,hWndOwner);

        if pCell.pPanel1<>nil then
          pCtlData^.hwndPanel1:=CreateCell(pCell.pPanel1^,hwndFrame,hWndOwner);
        if pCell.pPanel2<>nil then
          pCtlData^.hwndPanel2:=CreateCell(pCell.pPanel2^,hwndFrame,hWndOwner);

        WinSetWindowULong(hwndFrame, QWL_USER, ULONG(pCtlData));
      end;
  end;
  result:=hwndFrame;
end;

(* Function: CellProc
** Abstract: Subclass procedure for frame window
*)

function CellProc(Window: HWnd; Msg: ULong; Mp1,Mp2: MParam): MResult;
var pCtlData  :PCellCtlData;
    CellTbD   :PCellTb;
    itemCount :longint;
    lFlags    :longint;
    hwndBehind:HWND;
    hwndRC    :HWND;
    Swp,tSwp  :PSWP;
    cSwp      :PSWP;
    usClient  :smallword;
    itemCount2:smallword;
    hClient   :HWND;
    ptlSize   :POINTL;
    usPanel1,
    usPanel2  :PSWP;
    usWidth1,
    usWidth2  :smallword;
begin
  pCtlData :=nil;
  CellTbD  :=nil;
  itemCount:=0;
  result   :=0;

  pCtlData:=PCellCtlData(WinQueryWindowULong(Window,QWL_USER));
  if pCtlData=nil then exit;

  case Msg of
    WM_ADJUSTWINDOWPOS:begin
        CellTbD:=pCtlData^.CellTbD;
        Swp    :=PSWP(mp1);

        if (Swp^.fl and SWP_ZORDER<>0) and (CellTbD<>nil) then
        begin
          hwndBehind:=Swp^.hwndInsertBehind;
          while CellTbD<>nil do
          begin
            lFlags:=WinSendMsg(CellTbD^.Window,TKM_QUERY_FLAGS,0,0);
            if lFlags and TB_ATTACHED=0 then
            begin
              WinSetWindowPos(CellTbD^.Window,hwndBehind,0,0,0,0,SWP_ZORDER);
              hwndBehind:=CellTbD^.Window;
            end;
            CellTbD:=CellTbD^.pNext;
          end;
          Swp^.hwndInsertBehind:=hwndBehind;
        end;
      end;
    TKM_SEARCH_PARENT:begin
        if WinQueryWindowUShort(Window,QWS_ID)=mp1 then exit;

        if WinQueryWindowUShort(pCtlData^.hwndPanel1,QWS_ID)=mp1 then
          begin result:=MPARAM(Window); exit end;
        hwndRC:=HWND(WinSendMsg(pCtlData^.hwndPanel1,TKM_SEARCH_PARENT,mp1,0));
        if hwndRC<>0 then
          begin result:=MPARAM(hwndRC); exit end;

        if WinQueryWindowUShort(pCtlData^.hwndPanel2,QWS_ID)=mp1 then
          begin result:=MPARAM(Window); exit end;
        hwndRC:=HWND(WinSendMsg(pCtlData^.hwndPanel2,TKM_SEARCH_PARENT,mp1,0));
        if hwndRC<>0 then
          begin result:=MPARAM(hwndRC); exit end;

        exit;
      end;
    TKM_SEARCH_ID:begin
        CellTbD:=pCtlData^.CellTbD;

        while CellTbD<>nil do
        begin
          if WinQueryWindowUShort(CellTbD^.Window,QWS_ID)=mp1 then
            begin result:=MPARAM(CellTbD^.Window); exit end;

          hwndRC:=HWND(WinSendMsg(CellTbD^.Window,TKM_SEARCH_ID,mp1,0));
          if hwndRC<>0 then
            begin result:=MPARAM(hwndRC); exit end;

          CellTbD:=CellTbD^.pNext;
        end;

        if WinQueryWindowUShort(Window,QWS_ID)=mp1 then
          begin result:=MPARAM(Window); exit end;

        if WinQueryWindowUShort(pCtlData^.hwndPanel1,QWS_ID)=mp1 then
          begin result:=MPARAM(pCtlData^.hwndPanel1); exit end;
        hwndRC:=HWND(WinSendMsg(pCtlData^.hwndPanel1,TKM_SEARCH_ID,mp1,0));
        if hwndRC<>0 then
          begin result:=MPARAM(hwndRC); exit end;

        if WinQueryWindowUShort(pCtlData^.hwndPanel2,QWS_ID)=mp1 then
          begin result:=MPARAM(pCtlData^.hwndPanel2); exit end;
        hwndRC:=HWND(WinSendMsg(pCtlData^.hwndPanel2,TKM_SEARCH_ID,mp1,0));
        if hwndRC<>0 then
          begin result:=MPARAM(hwndRC); exit end;

        exit;
      end;
    WM_QUERYFRAMECTLCOUNT:begin
        itemCount:=pCtlData^.pOldProc(Window,msg,mp1,mp2);
        inc(itemCount,CountControls(pCtlData));
        result:=itemCount;
        exit;
      end;
    WM_FORMATFRAME:begin
      Swp     :=nil;
      usClient:=0;
      hClient :=HWND_TOP;

      itemCount :=pCtlData^.pOldProc(Window,msg,mp1,mp2);
      itemCount2:=CountControls(pCtlData);

      if (itemCount2=0) or (itemCount<1) then
      begin
        result:=itemCount;
        exit;
      end;

      Swp :=PSWP(mp1);
      cSwp:=Swp;

      usClient:=itemCount-1;
      inc(cSwp,usClient);
      hClient :=cSwp^.wnd;

      (*
      ** Cutting client window.
      ** If there are any attached toolbars, cut client window
      ** regarding to attachment type
      *)

      (* Toolbars attached to top and bottom sides *)

      CellTbD:=pCtlData^.CellTbD;

      while CellTbD<>nil do
      begin
        lFlags:=WinSendMsg(CellTbD^.Window,TKM_QUERY_FLAGS,0,0);

        if lFlags and TB_ATTACHED=0 then
        begin
          CellTbD:=CellTbD^.pNext;
          continue;
        end;

        RecalcTbDimensions(CellTbD^.Window,@ptlSize);
        tSwp:=Swp;
        inc(tSwp,itemCount);

        case lFlags and TB_ATTACHED of
          TB_ATTACHED_TP:begin
              tSwp^.x :=cSwp^.x;
              tSwp^.y :=cSwp^.y+cSwp^.cy-ptlSize.y;
              tSwp^.cx:=cSwp^.cx;
              tSwp^.cy:=ptlSize.y;
              tSwp^.fl:=SWP_SIZE or SWP_MOVE or SWP_SHOW;

              tSwp^.wnd:=CellTbD^.Window;
              tSwp^.hwndInsertBehind:=hClient;
              hClient:=tSwp^.wnd;

              dec(cSwp^.cy,ptlSize.y);
              inc(itemCount);
            end;
          TB_ATTACHED_BT:begin
              tSwp^.x :=cSwp^.x;
              tSwp^.y :=cSwp^.y;
              tSwp^.cx:=cSwp^.cx;
              tSwp^.cy:=ptlSize.y;
              tSwp^.fl:=SWP_SIZE or SWP_MOVE or SWP_SHOW;

              tSwp^.wnd:=CellTbD^.Window;
              tSwp^.hwndInsertBehind:=hClient;
              hClient:=tSwp^.wnd;

              dec(cSwp^.cy,ptlSize.y);
              inc(cSwp^.y ,ptlSize.y);
              inc(itemCount);
            end;
        end;
        CellTbD:=CellTbD^.pNext;
      end;

      (*Toolbars attached to left and right sides*)

      CellTbD:=pCtlData^.CellTbD;

      while CellTbD<>nil do
      begin
        lFlags:=WinSendMsg(CellTbD^.Window,TKM_QUERY_FLAGS,0,0);

        if lFlags and TB_ATTACHED=0 then
        begin
          CellTbD:=CellTbD^.pNext;
          continue;
        end;

        RecalcTbDimensions(CellTbD^.Window,@ptlSize);
        tSwp:=Swp;
        inc(tSwp,itemCount);

        case lFlags and TB_ATTACHED of
          TB_ATTACHED_LT:begin
              tSwp^.x :=cSwp^.x;
              tSwp^.y :=cSwp^.y;
              tSwp^.cx:=ptlSize.x;
              tSwp^.cy:=cSwp^.cy;
              tSwp^.fl:=SWP_SIZE or SWP_MOVE or SWP_SHOW;

              tSwp^.wnd:=CellTbD^.Window;
              tSwp^.hwndInsertBehind:=hClient;
              hClient:=tSwp^.wnd;

              dec(cSwp^.cx,ptlSize.x);
              inc(cSwp^.x ,ptlSize.x);
              inc(itemCount);
            end;
          TB_ATTACHED_RT:begin
              tSwp^.x :=cSwp^.x+cSwp^.cx-ptlSize.x;
              tSwp^.y :=cSwp^.y;
              tSwp^.cx:=ptlSize.x;
              tSwp^.cy:=cSwp^.cy;
              tSwp^.fl:=SWP_SIZE or SWP_MOVE or SWP_SHOW;

              tSwp^.wnd:=CellTbD^.Window;
              tSwp^.hwndInsertBehind:=hClient;
              hClient:=tSwp^.wnd;

              dec(cSwp^.cx,ptlSize.x);
              inc(itemCount);
            end;
        end;
        CellTbD:=CellTbD^.pNext;
      end;

      (*
      ** Placing panels.
      ** Remember client rect for future use
      ** They will save time when we start moving splitbar
      *)

      pCtlData^.rclBnd.xLeft   := cSwp^.x;
      pCtlData^.rclBnd.xRight  := cSwp^.x+cSwp^.cx;
      pCtlData^.rclBnd.yTop    := cSwp^.y+cSwp^.cy;
      pCtlData^.rclBnd.yBottom := cSwp^.y;

      if (pCtlData^.hwndPanel1=0) or (pCtlData^.hwndPanel2=0) or
        (pCtlData^.lType and CELL_HIDE<>0) then
      begin
        (*
        **single subwindow;
        **In this case we don't need a client window,
        **because of lack of splitbar.
        **Just copy all data from pSWP[usClient]
        **and replace some part of it
        *)

        tSwp:=Swp;
        inc(tSwp,itemCount);
        tSwp^:=cSwp^;
        tSwp^.fl:=tSwp^.fl or SWP_MOVE or SWP_SIZE;
        tSwp^.hwndInsertBehind:=HWND_TOP;
        cSwp^.cy:=0;

        tSwp^.wnd:=0;

        if (pCtlData^.hwndPanel1<>0) and (pCtlData^.lType and CELL_HIDE_1=0) then
          tSwp^.wnd:=pCtlData^.hwndPanel1;
        if (pCtlData^.hwndPanel2<>0) and (pCtlData^.lType and CELL_HIDE_2=0) then
          tSwp^.wnd:=pCtlData^.hwndPanel2;

        (* Increase number of controls *)

        if tSwp^.wnd<>0 then
        begin
          tSwp^.hwndInsertBehind:=hClient;
          hClient:=tSwp^.wnd;
          inc(itemCount);
        end;
      end else
      begin
        usPanel1:=Swp; inc(usPanel1,itemCount);
        usPanel2:=Swp; inc(usPanel2,itemCount+1);
        usWidth1:=0;
        usWidth2:=0;

        (* Just like case of one panel *)
        usPanel1^:=cSwp^;
        usPanel2^:=cSwp^;

        usPanel1^.fl:=usPanel1^.fl or SWP_MOVE or SWP_SIZE;
        usPanel2^.fl:=usPanel2^.fl or SWP_MOVE or SWP_SIZE;

        usPanel1^.hwndInsertBehind:=hClient;
        usPanel2^.hwndInsertBehind:=pCtlData^.hwndPanel1;

        usPanel1^.wnd:=pCtlData^.hwndPanel1;
        usPanel2^.wnd:=pCtlData^.hwndPanel2;

        hClient:=pCtlData^.hwndPanel2;

        if pCtlData^.lType and CELL_VSPLIT<>0 then
        begin
          if (pCtlData^.lType and CELL_FIXED<>0) and
            (pCtlData^.lType and (CELL_SIZE1 or CELL_SIZE2)<>0) and
              (pCtlData^.lSize>0) then
          begin
            (* Case of fixed panel with exact size *)

            if pCtlData^.lType and CELL_SIZE1<>0 then
            begin
              usWidth1:=pCtlData^.lSize;
              usWidth2:=cSwp^.cx-usWidth1;
            end else
            begin
              usWidth2:=pCtlData^.lSize;
              usWidth1:=cSwp^.cx-usWidth2;
            end;
          end else
          begin
            usWidth1:=(cSwp^.cx*pCtlData^.lSplit) div 100;
            usWidth2:=cSwp^.cx-usWidth1;
          end;

          if pCtlData^.lType and CELL_SPLITBAR<>0 then
          begin
            if pCtlData^.lType and CELL_SIZE1=0 then dec(usWidth2,SPLITBAR_WIDTH)
              else dec(usWidth1,SPLITBAR_WIDTH);

            cSwp^.cx:=SPLITBAR_WIDTH;
            cSwp^.x :=cSwp^.x + usWidth1;
          end else
          begin
            cSwp^.cx:=0;
            cSwp^.cy:=0;
          end;
          usPanel1^.cx:=usWidth1;
          inc(usPanel2^.x,usWidth1+cSwp^.cx);
          usPanel2^.cx:=usWidth2;
        end else
        begin
          if (pCtlData^.lType and CELL_FIXED<>0) and
            (pCtlData^.lType and (CELL_SIZE1 or CELL_SIZE2)<>0) and
              (pCtlData^.lSize>0) then
          begin
            (* Case of fixed panel with exact size *)

            if pCtlData^.lType and CELL_SIZE1<>0 then
            begin
              usWidth1:=pCtlData^.lSize;
              usWidth2:=cSwp^.cy-usWidth1;
            end else
            begin
              usWidth2:=pCtlData^.lSize;
              usWidth1:=cSwp^.cy-usWidth2;
            end;
          end else
          begin
            usWidth1:=(cSwp^.cy*pCtlData^.lSplit) div 100;
            usWidth2:=cSwp^.cy-usWidth1;
          end;

          if pCtlData^.lType and CELL_SPLITBAR<>0 then
          begin
            if pCtlData^.lType and CELL_SIZE1=0 then dec(usWidth2,SPLITBAR_WIDTH)
              else dec(usWidth1,SPLITBAR_WIDTH);

            cSwp^.cy:=SPLITBAR_WIDTH;
            cSwp^.y :=cSwp^.y + usWidth1;
          end else
          begin
            cSwp^.cx:=0;
            cSwp^.cy:=0;
          end;
          usPanel1^.cy:=usWidth1;
          inc(usPanel2^.y,usWidth1+cSwp^.cy);
          usPanel2^.cy:=usWidth2;
        end;
        inc(itemCount,2);
      end;
      result:=itemCount;
      exit
    end;
  end;
  result:=pCtlData^.pOldProc(Window,msg,mp1,mp2);
end;

(* Function: CellClientProc
** Abstract: Window procedure for Cell Client Window Class (splitbar)
*)

function CellClientProc(Window: HWnd; Msg: ULong; Mp1,Mp2: MParam): MResult;
var hwndFrame:HWND;
    pCtlData :PCellCtlData;
    hpsPaint :HPS;
    rclPaint :RECTL;
    ptlStart :array [0..SPLITBAR_WIDTH-1] of POINTL;
    ptlEnd   :array [0..SPLITBAR_WIDTH-1] of POINTL;
    pClTable :PClTableArray;
    ii       :longint;
    rclFrame :RECTL;
    rclBounds:RECTL;
    usNewRB,
    usSize   :smallword;
    lType    :longint;
    hwndTemp :HWND;
begin
  pCtlData:=nil;
  result  :=0;

  hwndFrame:=WinQueryWindow(Window,QW_PARENT);

  if hwndFrame<>0 then
    pCtlData:=PCellCtlData(WinQueryWindowULong(hwndFrame,QWL_USER));
  if (hwndFrame=0) or (pCtlData=nil) then
  begin
    result:=WinDefWindowProc(Window,msg,mp1,mp2);
    exit
  end;

  case msg of
    WM_ACTIVATE,WM_SETFOCUS:exit;
    WM_PAINT:begin
        hpsPaint:=WinBeginPaint(Window,0,nil);
        WinQueryWindowRect(Window,rclPaint);

        if pCtlData^.lType and CELL_VSPLIT<>0 then
        begin
          for ii:=0 to SPLITBAR_WIDTH-1 do
          begin
            ptlStart[ii].x:=rclPaint.xLeft + ii;
            ptlStart[ii].y:=rclPaint.yTop;

            ptlEnd[ii].x:=rclPaint.xLeft + ii;
            ptlEnd[ii].y:=rclPaint.yBottom;
          end;
          if pCtlData^.lType and CELL_FIXED<>0 then
            pClTable:=@lColor else pClTable:=@lColor2;
        end else
        begin
          for ii:=0 to SPLITBAR_WIDTH-1 do
          begin
            ptlStart[ii].x:=rclPaint.xLeft;
            ptlStart[ii].y:=rclPaint.yBottom+ii;

            ptlEnd[ii].x:=rclPaint.xRight;
            ptlEnd[ii].y:=rclPaint.yBottom+ii;
          end;
          if pCtlData^.lType and CELL_FIXED<>0 then
            pClTable:=@lColor2 else pClTable:=@lColor;
        end;
        for ii:=0 to SPLITBAR_WIDTH-1 do
        begin
          GpiSetColor(hpsPaint,pClTable^[ii]);
          GpiMove(hpsPaint,ptlStart[ii]);
          GpiLine(hpsPaint,ptlEnd[ii]);
        end;
        WinEndPaint(hpsPaint);
        exit
      end;
    WM_MOUSEMOVE:if pCtlData^.lType and CELL_FIXED=0 then
      begin
        if pCtlData^.lType and CELL_VSPLIT<>0 then
          WinSetPointer(HWND_DESKTOP,WinQuerySysPointer(HWND_DESKTOP,SPTR_SIZEWE,FALSE))
        else
          WinSetPointer(HWND_DESKTOP,WinQuerySysPointer(HWND_DESKTOP,SPTR_SIZENS,FALSE));
        exit
      end;
    WM_BUTTON1DOWN:if pCtlData^.lType and CELL_FIXED=0 then
      begin
        WinQueryWindowRect(Window,rclFrame);

        rclBounds:=pCtlData^.rclBnd;
        WinMapWindowPoints(hwndFrame,HWND_DESKTOP,PPOINTL(@rclBounds)^,2);

        if TrackRectangle(Window,rclFrame,@rclBounds)=1 then
        begin
          if pCtlData^.lType and CELL_VSPLIT<>0 then
          begin
            usNewRB:=rclFrame.xLeft-rclBounds.xLeft;
            usSize :=rclBounds.xRight-rclBounds.xLeft;
          end else
          begin
            usNewRB:=rclFrame.yBottom-rclBounds.yBottom;
            usSize :=rclBounds.yTop-rclBounds.yBottom;
          end;
            pCtlData^.lSplit:=(usNewRB*100) div usSize;
            if pCtlData^.lSplit>CELL_TOP_LIMIT then pCtlData^.lSplit:=CELL_TOP_LIMIT;
            if pCtlData^.lSplit<CELL_BOTTOM_LIMIT then pCtlData^.lSplit:=CELL_BOTTOM_LIMIT;
            WinSendMsg(hwndFrame,WM_UPDATEFRAME,0,0);
        end;
        exit;
      end;
    WM_BUTTON2DOWN:if pCtlData^.lType and CELL_FIXED=0 then
      begin
        lType:=pCtlData^.lType and (CELL_VSPLIT or CELL_HSPLIT);

        pCtlData^.lType:=pCtlData^.lType and not (CELL_VSPLIT or CELL_HSPLIT);
        if lType and CELL_VSPLIT<>0 then
          pCtlData^.lType:=pCtlData^.lType or CELL_HSPLIT
        else
          pCtlData^.lType:=pCtlData^.lType or CELL_VSPLIT;

        (* Swap subwindows *)

        if lType and CELL_VSPLIT<>0 then
        begin
          hwndTemp:=pCtlData^.hwndPanel1;
          pCtlData^.hwndPanel1:=pCtlData^.hwndPanel2;
          pCtlData^.hwndPanel2:=hwndTemp;
          pCtlData^.lType:=pCtlData^.lType xor CELL_SWAP;
        end;

        if pCtlData^.lType and CELL_HIDE_1<>0 then
        begin
          pCtlData^.lType:=pCtlData^.lType and not CELL_HIDE_1;
          pCtlData^.lType:=pCtlData^.lType or CELL_HIDE_2;
        end else
        if pCtlData^.lType and CELL_HIDE_2<>0 then
        begin
          pCtlData^.lType:=pCtlData^.lType and not CELL_HIDE_2;
          pCtlData^.lType:=pCtlData^.lType or CELL_HIDE_1;
        end;

        if pCtlData^.lType and CELL_SIZE1<>0 then
        begin
          pCtlData^.lType:=pCtlData^.lType and not CELL_SIZE1;
          pCtlData^.lType:=pCtlData^.lType or CELL_SIZE2;
        end else
        if pCtlData^.lType and CELL_SIZE2<>0 then
        begin
          pCtlData^.lType:=pCtlData^.lType and not CELL_SIZE2;
          pCtlData^.lType:=pCtlData^.lType or CELL_SIZE1;
        end;

        WinSendMsg(hwndFrame,WM_UPDATEFRAME,0,0);
        exit
      end;
  end;
  result:=WinDefWindowProc(Window,msg,mp1,mp2);
end;

(*****************************************************************************
** Toolbar implementation
*)

(* Function: CreateTb
** Abstract: Creates Toolbar for a gived TbDef
*)

function CreateTb(var pTb:TbDef; hWndParent, hWndOwner:HWND):HWND;
var swp        :os2pmapi.swp;
    hwndClient :HWND;
    hwndTb     :HWND;
    lCount     :longint;
    ptlSize,
    ptlFSize   :POINTL;
    flCreate   :longint;
    TbCtlD     :PTbCtlData;
    TbItemD    :PTbItemData;
    tmpItemD   :PTbItemData;
    tbItem     :plong;
    TbCtlLen,
    TbItemLen  :longint;
    cButtText  :array [byte] of char;
begin
  hwndTb:=NULLHANDLE;
  result:=NULLHANDLE;

  lCount:=0;
  tbItem:=pTb.tbItems;
  while tbItem^<>0 do begin inc(lCount); inc(tbItem) end;

  TbCtlLen:=sizeof(TbCtlData)+sizeof(HWND)*lCount;
  getmem(TbCtlD,TbCtlLen);

  if TbCtlD=nil then exit;

  TbItemLen:=sizeof(TbItemData)*lCount;
  getmem(TbItemD,TbItemLen);

  if TbItemD=nil then
  begin
    freemem(TbCtlD,TbCtlLen);
    exit;
  end;

  fillchar(TbCtlD^ ,TbCtlLen ,#0);
  fillchar(TbItemD^,TbItemLen,#0);

  TbCtlD^.lCount :=lCount;
  TbCtlD^.bBubble:=pTb.lType and TB_BUBBLE<>0;

  pTb.lType:=pTb.lType and TB_ALLOWED;

  (*
  **Some checks:
  ** if toolbar attached, they should be properly
  ** oriented. I.e. toolbar attached to top or
  ** bottom, can't be vertical.
  *)

  if pTb.lType and (TB_ATTACHED_TP or TB_ATTACHED_BT)<>0 then
    pTb.lType:=pTb.lType and not TB_VERTICAL;

  TbCtlD^.lState:=pTb.lType;
  TbCtlD^.hwndParent:=hWndParent;

  if pTb.lType and TB_ATTACHED=0 then hWndParent:=HWND_DESKTOP;

  if pTb.lType and TB_ATTACHED<>0 then
    flCreate:=FCF_BORDER or FCF_NOBYTEALIGN
  else
    flCreate:=FCF_DLGBORDER or FCF_NOBYTEALIGN;

  hwndTb:=WinCreateStdWindow(hWndParent, WS_CLIPCHILDREN or WS_CLIPSIBLINGS or
    WS_PARENTCLIP, flCreate, TB_CLIENT, '', 0, 0, pTb.ulID, @hwndClient);

  if hwndTb=0 then
  begin
    freemem(TbItemD,TbItemLen);
    freemem(TbCtlD,TbCtlLen);
    exit;
  end;

  if TbCtlD^.lState and TB_VERTICAL<>0 then
    begin ptlSize.x:=0; ptlSize.y:=HAND_SIZE end
  else
    begin ptlSize.x:=HAND_SIZE; ptlSize.y:=0 end;

  for lCount:=0 to TbCtlD^.lCount-1 do
  begin
    tbItem:=pTb.tbItems;
    inc(tbItem,lCount);
    if tbItem^=TB_SEPARATOR then
      TbCtlD^.hItems[lCount]:=WinCreateWindow(hwndTb, TB_SEPCLASS, '', 0, 0, 0,
        TB_SEP_SIZE, TB_SEP_SIZE, hwndTb, HWND_TOP, tbItem^, nil, nil)
    else
    begin
      flCreate:=BS_PUSHBUTTON or BS_BITMAP or BS_AUTOSIZE or BS_NOPOINTERFOCUS;

      GenResIDStr(cButtText,tbItem^);

      TbCtlD^.hItems[lCount]:=WinCreateWindow(hwndTb, WC_BUTTON, cButtText,
        flCreate, -1, -1, -1, -1, hWndOwner, HWND_TOP, tbItem^, nil, nil);

      tmpItemD:=TbItemD;
      inc(tmpItemD,lCount);
      @tmpItemD^.pOldProc:=WinSubclassWindow(TbCtlD^.hItems[lCount],BtProc);
      WinSetWindowULong(TbCtlD^.hItems[lCount],QWL_USER,ULONG(tmpItemD))
    end;

    WinQueryWindowPos(TbCtlD^.hItems[lCount],swp);

    if TbCtlD^.lState and TB_VERTICAL<> 0 then
    begin
      if swp.cx>ptlSize.x then ptlSize.x:=swp.cx;
      inc(ptlSize.y,swp.cy)
    end else
    begin
      if swp.cy>ptlSize.y then ptlSize.y:=swp.cy;
      inc(ptlSize.x,swp.cx)
    end;
  end;

  (*
  ** Now we have calculated client window size for toolbar
  ** Recalculate its proper size
  *)

  WinSendMsg(hwndTb,WM_QUERYBORDERSIZE,MPFROMP(@ptlFSize),0);
  inc(ptlSize.x,ptlFSize.x*2);
  inc(ptlSize.y,ptlFSize.y*2);

  @TbCtlD^.pOldProc:=WinSubclassWindow(hwndTb,TbProc);
  WinSetWindowULong(hwndTb,QWL_USER,ULONG(TbCtlD));

  WinQueryWindowPos(hWndOwner,swp);

  WinSetWindowPos(hwndTb, 0, swp.x+HAND_SIZE div 2, swp.y+HAND_SIZE div 2,
    ptlSize.x, ptlSize.y, SWP_MOVE or SWP_SIZE or SWP_SHOW);
  result:=hwndTb
end;

(* Function: BtProc
** Abstract: Subclass procedure for buttons
*)

function BtProc(Window: HWnd; Msg: ULong; Mp1,Mp2: MParam): MResult;
var TbCtlD     :PTbCtlData;
    TbItemD    :PTbItemData;
    hwndFrame  :HWND;
    hwndBubbleClient:HWND;
    ulStyle    :longint;
    hpsTemp    :HPS;
    lHight,
    lWidth     :longint;
    txtPointl  :array [0..TXTBOX_COUNT-1] of POINTL;
    ptlWork    :POINTL;
    ulColor    :longint;
    rclButton  :RECTL;
begin
  hwndFrame:=WinQueryWindow(Window,QW_PARENT);
  TbCtlD   :=PTbCtlData(WinQueryWindowULong(hwndFrame,QWL_USER));
  TbItemD  :=PTbItemData(WinQueryWindowULong(Window,QWL_USER));

  case msg of
    WM_TIMER:
      if TbCtlD^.hwndBubble<>0 then
      begin
        WinDestroyWindow(TbCtlD^.hwndBubble);
        TbCtlD^.hwndBubble:=0;
        WinStopTimer(Anchor,Window,1);
      end;
    WM_MOUSEMOVE:if (TbCtlD^.lState and TB_BUBBLE<>0) and
        TbCtlD^.bBubble and ((WinQueryActiveWindow(HWND_DESKTOP)=hwndFrame) or
          (WinQueryActiveWindow(HWND_DESKTOP)=TbCtlD^.hwndParent)) and
            (TbCtlD^.hwndLast<>Window) then
      begin
        if TbCtlD^.hwndBubble<>0 then
        begin
          WinDestroyWindow(TbCtlD^.hwndBubble);
          TbCtlD^.hwndBubble:=0;
          WinStopTimer(Anchor,TbCtlD^.hwndLast,1);
        end;

        if TbCtlD^.hwndBubble=0 then
        begin
          ulStyle:=FCF_BORDER or FCF_NOBYTEALIGN;
          hpsTemp:=0;
          ptlWork.x:=0;
          ptlWork.y:=0;
          ulColor:=CLR_PALEGRAY;

          TbCtlD^.hwndLast:=Window;
          TbCtlD^.hwndBubble:=WinCreateStdWindow(HWND_DESKTOP, 0, ulStyle,
            WC_STATIC, '', SS_TEXT or DT_LEFT or DT_VCENTER, NULLHANDLE,
              TB_BUBBLEID, @hwndBubbleClient);

          WinSetPresParam(hwndBubbleClient,PP_FONTNAMESIZE,strlen(ppFont)+1,ppFont);
          WinSetPresParam(hwndBubbleClient,PP_BACKGROUNDCOLORINDEX,sizeof(ulColor),@ulColor);

          if TbItemD^.cText[0]=#0 then
            WinLoadString(Anchor, 0, WinQueryWindowUShort(Window,QWS_ID),
              sizeof(TbItemD^.cText), TbItemD^.cText);

          WinSetWindowText(hwndBubbleClient, TbItemD^.cText);

          WinMapWindowPoints(Window, HWND_DESKTOP, ptlWork, 1);

          hpsTemp:=WinGetPS(hwndBubbleClient);
          GpiQueryTextBox(hpsTemp, strlen(TbItemD^.cText), TbItemD^.cText,
            TXTBOX_COUNT,PPOINTL(@txtPointl[0])^);

          WinReleasePS(hpsTemp);

          lWidth:=txtPointl[TXTBOX_TOPRIGHT].x-txtPointl[TXTBOX_TOPLEFT].x+
            WinQuerySysValue(HWND_DESKTOP,SV_CYDLGFRAME)*2;

          lHight:=txtPointl[TXTBOX_TOPLEFT].y-txtPointl[TXTBOX_BOTTOMLEFT].y+
            WinQuerySysValue(HWND_DESKTOP,SV_CXDLGFRAME)*2;

          if TbCtlD^.lState and TB_VERTICAL=0 then dec(ptlWork.y,lHight) else
          begin
            WinQueryWindowRect(Window,rclButton);
            inc(ptlWork.x,rclButton.xRight-rclButton.xLeft);
          end;

          WinSetWindowPos(TbCtlD^.hwndBubble, HWND_TOP, ptlWork.x, ptlWork.y,
            lWidth, lHight, SWP_SIZE or SWP_MOVE or SWP_SHOW);

          WinStartTimer(Anchor, Window, 1, 1500);
        end;
      end;
  end;
  result:=TbItemD^.pOldProc(Window, msg, mp1, mp2);
end;

(* Function: TbProc
** Abstract: Subclass procedure for toolbar window
*)

function TbProc(Window: HWnd; Msg: ULong; Mp1,Mp2: MParam): MResult;
var TbCtlD    :PTbCtlData;
    itemCount :longint;

    lOffset   :longint;
    lCount    :longint;
    cSwp      :PSWP;
    tSwp,iSwp :PSWP;
    Swp       :os2pmapi.swp;
begin
  result:=0;
  TbCtlD:=PTbCtlData(WinQueryWindowULong(Window,QWL_USER));
  if TbCtlD=nil then exit;

  case msg of
    (* Internal messages *)
    TKM_SEARCH_ID:begin
        for itemCount:=0 to TbCtlD^.lCount-1 do
          if WinQueryWindowUShort(TbCtlD^.hItems[itemCount],QWS_ID)=ULONG(mp1) then
            begin result:=TbCtlD^.hItems[itemCount]; exit end;
        exit;
      end;
    TKM_QUERY_FLAGS:begin
        result:=TbCtlD^.lState;
        exit
      end;

    (* Standard messages *)

    WM_QUERYFRAMECTLCOUNT:begin
        itemCount:=TbCtlD^.pOldProc(Window, msg, mp1, mp2);
        inc(itemCount,TbCtlD^.lCount);

        result:=itemCount;
        exit;
      end;

    WM_FORMATFRAME:begin
        lOffset :=0;

        itemCount:=TbCtlD^.pOldProc(Window, msg, mp1, mp2);

        cSwp:=PSWP(PVOIDFROMMP(mp1));
        tSwp:=cSwp;

        while tSwp^.wnd<>WinWindowFromID(Window,FID_CLIENT) do inc(tSwp);


        if TbCtlD^.lState and TB_VERTICAL<>0 then
          lOffset:=tSwp^.cy-HAND_SIZE
        else
          lOffset:=HAND_SIZE+1;

        for lCount:=0 to TbCtlD^.lCount-1 do
        begin
          WinQueryWindowPos(TbCtlD^.hItems[lCount],swp);

          iSwp:=cSwp;
          inc(iSwp,itemCount);

          if TbCtlD^.lState and TB_VERTICAL<>0 then
          begin
            iSwp^.x:=tSwp^.x;
            iSwp^.y:=lOffset+tSwp^.y-swp.cy
          end else
          begin
            iSwp^.x:=tSwp^.x+lOffset;
            iSwp^.y:=tSwp^.y;
          end;

          iSwp^.cx := swp.cx;
          iSwp^.cy := swp.cy;
          iSwp^.fl := SWP_SIZE or SWP_MOVE or SWP_SHOW;
          iSwp^.wnd:= TbCtlD^.hItems[lCount];
          iSwp^.hwndInsertBehind:= HWND_TOP;

          if TbCtlD^.lState and TB_VERTICAL<>0 then dec(lOffset,swp.cy)
            else inc(lOffset,swp.cx);

          inc(itemCount);
        end;

        if TbCtlD^.lState and TB_VERTICAL<>0 then
        begin
          inc(tSwp^.y,tSwp^.cy-HAND_SIZE);
          tSwp^.cy:=HAND_SIZE;
        end else
          tSwp^.cx:=HAND_SIZE;
        result:=itemCount;
        exit;
      end;
  end;
  result:=TbCtlD^.pOldProc(Window, msg, mp1, mp2);
end;

(* Function: TbSeparatorProc
** Abstract: Window procedure for Toolbar Separator Window Class
*)

function TbSeparatorProc(Window: HWnd; Msg: ULong; Mp1,Mp2: MParam): MResult;
var hpsPaint:HPS;
    rclPaint:RECTL;
begin
  result:=0;
  case msg of
    WM_PAINT:begin
        hpsPaint:=WinBeginPaint(Window, 0, nil);
        WinQueryWindowRect(Window, rclPaint);
        WinFillRect(hpsPaint, rclPaint, CLR_PALEGRAY);
        WinEndPaint(hpsPaint);
        exit;
      end;
  end;
  result:=WinDefWindowProc(Window, msg, mp1, mp2);
end;

(* Function: RecalcTbDimensions
** Abstract: Recalculate Toolbar window dimensions
*)

procedure RecalcTbDimensions(Window:HWND; pSize:PPOINTL);
var  lCount   :longint;
     TbCtlD   :PTbCtlData;
     ptlSize  :POINTL;
     ptlFSize :POINTL;
     swp      :os2pmapi.swp;
begin
  TbCtlD:=PTbCtlData(WinQueryWindowULong(Window, QWL_USER));

  if TbCtlD^.lState and TB_VERTICAL<>0 then
    begin ptlSize.x:=0; ptlSize.y:=HAND_SIZE end
  else
    begin ptlSize.x:=HAND_SIZE; ptlSize.y:=0 end;

  for lCount:=0 to TbCtlD^.lCount-1 do
  begin
    WinQueryWindowPos(TbCtlD^.hItems[lCount],swp);
    if TbCtlD^.lState and TB_VERTICAL<>0 then
    begin
      if swp.cx>ptlSize.x then ptlSize.x:=swp.cx;
      inc(ptlSize.y,swp.cy)
    end else
    begin
      if swp.cy>ptlSize.y then ptlSize.y:=swp.cy;
      inc(ptlSize.x,swp.cx)
    end;
  end;

  WinSendMsg(Window, WM_QUERYBORDERSIZE, MPFROMP(@ptlFSize), 0);
  inc(ptlSize.x,ptlFSize.x*2);
  inc(ptlSize.y,ptlFSize.y*2);

  if pSize<>nil then pSize^:=ptlSize else
    WinSetWindowPos(Window, 0, 0, 0, ptlSize.x, ptlSize.y, SWP_SIZE)
end;

(* Function: TrackRectangle
** Abstract: Tracks given rectangle.
**
** If rclBounds is NULL, then track rectangle on entire desktop.
** rclTrack is in window coorditates and will be mapped to
** desktop.
*)

function TrackRectangle(hwndBase:HWND; var rclTrack:RECTL; rclBounds:PRECTL):LONG;
var track   :TRACKINFO;
    ptlSize :POINTL;
begin
  result:=0;
  track.cxBorder:=1;
  track.cyBorder:=1;
  track.cxGrid  :=1;
  track.cyGrid  :=1;
  track.cxKeyboard:=1;
  track.cyKeyboard:=1;

  if rclBounds<>nil then track.rclBoundary:=rclBounds^ else
  begin
    track.rclBoundary.yTop   := 3000;
    track.rclBoundary.xRight := 3000;
    track.rclBoundary.yBottom:=-3000;
    track.rclBoundary.xLeft  :=-3000;
  end;

  track.rclTrack:=rclTrack;

  WinMapWindowPoints(hwndBase, HWND_DESKTOP, PPOINTL(@track.rclTrack)^, 2);

  track.ptlMinTrackSize.x:= track.rclTrack.xRight - track.rclTrack.xLeft;
  track.ptlMinTrackSize.y:= track.rclTrack.yTop   - track.rclTrack.yBottom;
  track.ptlMaxTrackSize.x:= track.rclTrack.xRight - track.rclTrack.xLeft;
  track.ptlMaxTrackSize.y:= track.rclTrack.yTop   - track.rclTrack.yBottom;

  track.fs:= TF_MOVE or TF_ALLINBOUNDARY or TF_GRID;

  if WinTrackRect(HWND_DESKTOP, 0, track) then result:=1;

  if result=1 then
  begin
    if WinEqualRect(Anchor,rclTrack,track.rclTrack) then
      begin result:=-1; exit end;
    rclTrack:=track.rclTrack
  end;
end;

(* Function: TbClientProc
** Abstract: Window procedure for Toolbar Client Window Class
*)

function TbClientProc(Window: HWnd; Msg: ULong; Mp1,Mp2: MParam): MResult;
var hwndFrame :HWND;
    TbCtlD    :PTbCtlData;
    rclPaint  :RECTL;
    hpsPaint  :HPS;
    ptlWork   :POINTL;
    iShift    :longint;
    ptlPoint  :POINTL;
    swp       :os2pmapi.swp;
    rclOwner  :RECTL;
    rclFrame  :RECTL;
    lState    :longint;
    lBorderX  :longint;
    lBorderY  :longint;
    ptlSize   :POINTL;
begin
  hwndFrame:=WinQueryWindow(Window,QW_PARENT);
  TbCtlD   :=PTbCtlData(WinQueryWindowULong(hwndFrame,QWL_USER));
  result   :=0;

  case msg of
    WM_ERASEBACKGROUND:begin
        WinFillRect(HPS(mp1),PRECTL(mp2)^,SYSCLR_BUTTONMIDDLE);
        exit;
      end;
    WM_PAINT:begin
        hpsPaint:=WinBeginPaint(Window,0,nil);
        WinQueryWindowRect(Window,rclPaint);

        WinFillRect(hpsPaint,rclPaint,CLR_PALEGRAY);

        GpiSetColor(hpsPaint,CLR_WHITE);

        ptlWork.x:= rclPaint.xLeft   + 2;
        ptlWork.y:= rclPaint.yBottom + 2;
        GpiMove(hpsPaint, ptlWork);
        ptlWork.y:= rclPaint.yTop    - 2;
        GpiLine(hpsPaint, ptlWork);
        ptlWork.x:= rclPaint.xRight  - 2;
        GpiLine(hpsPaint, ptlWork);

        GpiSetColor(hpsPaint,CLR_BLACK);

        ptlWork.y:= rclPaint.yBottom + 2;
        GpiLine(hpsPaint, ptlWork);
        ptlWork.x:= rclPaint.xLeft   + 2;
        GpiLine(hpsPaint, ptlWork);

        WinEndPaint(hpsPaint);
        exit;
      end;
    WM_MOUSEMOVE:begin
        WinSetPointer(HWND_DESKTOP, WinQuerySysPointer(HWND_DESKTOP, SPTR_MOVE, FALSE));
        exit;
      end;
    WM_BUTTON2DBLCLK: (* Switch bubble help on/off *)
      if TbCtlD^.lState and TB_BUBBLE<>0 then TbCtlD^.bBubble:=not TbCtlD^.bBubble;
    WM_BUTTON1DBLCLK: (* Flip horisontal/vertical *)
      begin
        (* attached toolbar can't be flipped *)
        if TbCtlD^.lState and TB_ATTACHED<>0 then exit;

        TbCtlD^.lState:=TbCtlD^.lState xor TB_VERTICAL;
        WinShowWindow(hwndFrame, FALSE);
        RecalcTbDimensions(hwndFrame, nil);

        (*
        ** Setup new position
        ** New positon should be aligned to mouse cursor
        *)

        WinQueryPointerPos(HWND_DESKTOP,ptlPoint);
        WinQueryWindowPos(hwndFrame, swp);

        if TbCtlD^.lState and TB_VERTICAL<>0 then
          WinSetWindowPos(hwndFrame, 0, ptlPoint.x - swp.cx div 2,
            ptlPoint.y - swp.cy + HAND_SIZE div 2, 0, 0, SWP_MOVE)
        else
          WinSetWindowPos(hwndFrame, 0, ptlPoint.x - HAND_SIZE div 2,
            ptlPoint.y - swp.cy div 2, 0, 0, SWP_MOVE);
        WinShowWindow(hwndFrame, TRUE);
        exit
      end;
    WM_BUTTON1DOWN:begin
        lState:=0;

        RecalcTbDimensions(hwndFrame, @ptlSize);

        rclFrame.xLeft  := 0;
        rclFrame.yBottom:= 0;
        rclFrame.yTop   := ptlSize.y;
        rclFrame.xRight := ptlSize.x;

        if (TbCtlD^.lState and TB_ATTACHED<>0) and (TbCtlD^.lState and TB_VERTICAL<>0) then
        begin
          WinQueryWindowRect(hwndFrame, rclOwner);

          iShift:=rclOwner.yTop-rclOwner.yBottom-ptlSize.y;
          inc(rclFrame.yBottom,iShift);
          inc(rclFrame.yTop,iShift);
        end;

        if TrackRectangle(hwndFrame, rclFrame, nil)=1 then
        begin
          (*
          ** Check new position for the toolbar
          ** NOTE: order of checks is important
          *)
          WinQueryWindowRect(TbCtlD^.hwndParent,rclOwner);

          (* Map both points to the desktop *)
          WinMapWindowPoints(TbCtlD^.hwndParent, HWND_DESKTOP, PPOINTL(@rclOwner)^, 2);

          (* Cut owner rect by titlebar and menu hight *)
          lBorderX:= WinQuerySysValue(HWND_DESKTOP, SV_CXDLGFRAME);
          lBorderY:= WinQuerySysValue(HWND_DESKTOP, SV_CYDLGFRAME);

          if WinWindowFromID(TbCtlD^.hwndParent,FID_MENU)<>0 then
            dec(rclOwner.yTop,WinQuerySysValue(HWND_DESKTOP,SV_CYMENU));

          if WinWindowFromID(TbCtlD^.hwndParent,FID_TITLEBAR)<>0 then
            dec(rclOwner.yTop,WinQuerySysValue(HWND_DESKTOP,SV_CYTITLEBAR));

          lState:=0;
          if (rclFrame.xLeft>=rclOwner.xLeft-lBorderX*2) and
            (rclFrame.xLeft<=rclOwner.xLeft+lBorderX*2) then lState:=TB_ATTACHED_LT;

          if (rclFrame.yTop>=rclOwner.yTop-lBorderY*2) and
            (rclFrame.yTop<=rclOwner.yTop+lBorderY*2) then lState:=TB_ATTACHED_TP;

          if (rclFrame.xRight>=rclOwner.xRight-lBorderX*2) and
            (rclFrame.xRight<=rclOwner.xRight+lBorderX*2) then lState:=TB_ATTACHED_RT;

          if (rclFrame.yBottom>=rclOwner.yBottom-lBorderY*2) and
            (rclFrame.yBottom<=rclOwner.yBottom+lBorderY*2) then lState:=TB_ATTACHED_BT;

          WinShowWindow(hwndFrame, FALSE);

          if (TbCtlD^.lState and TB_ATTACHED=0) and (lState=0) then
          begin
            (* Toolbar is not attached and will not be attached
               this time. Just change its position.
             *)
            WinSetWindowPos(hwndFrame,0,rclFrame.xLeft,rclFrame.yBottom,0,0,SWP_MOVE);
          end;

          if TbCtlD^.lState and TB_ATTACHED<>0 then
          begin
            WinSetWindowBits(hwndFrame, QWL_STYLE, 0, FS_BORDER);
            WinSetWindowBits(hwndFrame, QWL_STYLE, FS_DLGBORDER, FS_DLGBORDER);
            WinSendMsg(hwndFrame, WM_UPDATEFRAME, FCF_SIZEBORDER, 0);

            TbCtlD^.lState:=TbCtlD^.lState and not TB_ATTACHED;
            WinSetParent(hwndFrame, HWND_DESKTOP, FALSE);
            RecalcTbDimensions(hwndFrame, nil);

            WinQueryPointerPos(HWND_DESKTOP,ptlPoint);
            WinQueryWindowPos(hwndFrame, swp);

            if TbCtlD^.lState and TB_VERTICAL<>0 then
              WinSetWindowPos(hwndFrame, 0, ptlPoint.x - swp.cx div 2,
                ptlPoint.y - swp.cy + HAND_SIZE div 2, 0, 0, SWP_MOVE)
            else
              WinSetWindowPos(hwndFrame, 0, ptlPoint.x - HAND_SIZE div 2,
                ptlPoint.y - swp.cy div 2, 0, 0, SWP_MOVE)
          end;

          if lState<>0 then
          begin
            TbCtlD^.lState:=TbCtlD^.lState or lState;

            WinSetWindowBits(hwndFrame, QWL_STYLE, 0, FS_DLGBORDER);
            WinSetWindowBits(hwndFrame, QWL_STYLE, FS_BORDER, FS_BORDER);
            WinSendMsg(hwndFrame, WM_UPDATEFRAME, FCF_SIZEBORDER, 0);

            WinSetFocus(HWND_DESKTOP, TbCtlD^.hwndParent);
            WinSetParent(hwndFrame, TbCtlD^.hwndParent, FALSE);

            if (lState and (TB_ATTACHED_LT or TB_ATTACHED_RT)<>0) and
              (TbCtlD^.lState and TB_VERTICAL=0) then
            begin
              (*
              ** toolbar is horisontal, but we need to
              ** attach them to vertical side
              *)
              TbCtlD^.lState:=TbCtlD^.lState xor TB_VERTICAL
            end;

            if (lState and (TB_ATTACHED_TP or TB_ATTACHED_BT)<>0) and
              (TbCtlD^.lState and TB_VERTICAL<>0) then
            begin
              (*
              **toolbar is vertical, but we need to
              **attach them to horizontal side
              *)
              TbCtlD^.lState:=TbCtlD^.lState xor TB_VERTICAL
            end;
            RecalcTbDimensions(hwndFrame, nil);
          end;

          WinSendMsg(TbCtlD^.hwndParent, WM_UPDATEFRAME, 0, 0);
          WinShowWindow(hwndFrame, TRUE);
          WinSetWindowPos(hwndFrame, HWND_TOP, 0, 0, 0, 0, SWP_ZORDER);

          exit;
        end;
      end;
  end;
  result:=WinDefWindowProc(Window, msg, mp1, mp2);
end;

(* Function: CreateToolbar
** Abstract: Creates toolbar for cell frame window
*)

Procedure CreateToolbar(hwndCell:HWND; var pTb:TbDef);
var CtlD  :PCellCtlData;
    CellD :PCellTb;
    hwndTb:HWND;
begin
  if hwndCell=0 then exit;

  CtlD:=PCellCtlData(WinQueryWindowULong(hwndCell, QWL_USER));
  if CtlD=nil then exit;

  hwndTb:=CreateTb(pTb,hwndCell,hwndCell);
  if hwndTb=0 then exit;

  new(CellD);
  if CellD=nil then exit;

  fillchar(CellD^,sizeof(CellTb),#0);

  CellD^.Window:= hwndTb;
  CellD^.pNext := CtlD^.CellTbD;
  CtlD^.CellTbD:= CellD;

  WinSendMsg(hwndCell, WM_UPDATEFRAME, 0, 0);
end;

(* Function: CellWindowFromID
** Abstract: Locate control window with given ID
*)

Function CellWindowFromID(hwndCell:HWND; ulID:longint):HWND;
begin
  result:=WinSendMsg(hwndCell, TKM_SEARCH_ID, ulID, 0);
end;

(* Function: CellWindowFromID
** Abstract: Locate parent window for window with given ID
*)

Function CellParentWindowFromID(hwndCell:HWND; ulID:longint):HWND;
begin
  result:=WinSendMsg(hwndCell, TKM_SEARCH_PARENT, ulID, 0);
end;

(* Function: GenResIDStr
** Abstract: Generate string '#nnnn' for a given ID for using with Button
**           controls
*)

Procedure GenResIDStr(buff:pchar; ulID:longint);
var  str :pchar;
     slen:longint;
begin
  slen:=0;
  buff^:='#';
  inc(buff);
  str:=buff;

  repeat
    str^:=chr(ulID mod 10+ord('0'));
    inc(str);
    ulID:=ulID div 10;
    inc(slen);
  until ulID=0;

  str^:=#0;
  dec(str);

  while str>buff do
  begin
    buff^:=char(ord(buff^) xor ord(str^));
    str^ :=char(ord(str^) xor ord(buff^));
    buff^:=char(ord(buff^) xor ord(str^));
    dec(str);
    inc(buff);
  end;
end;

end.
