(*
** Module   :MULTIBAR.C
** Abstract :Test and sample application for Cell toolkit procedures.
**
** Copyright (C) Sergey I. Yevtushenko
** Log: Sun  08/02/98   Refined
**
*)
uses os2def,os2pmapi,cell,strings;

{$PMTYPE PM}

{$I multibar.inc}

{$R status.res}

(* Local procedures *)

var hwndFrame:HWND;

function MainClientProc(Window: HWnd; Msg: ULong; Mp1,Mp2: MParam): MResult; cdecl; forward;

(* Static Variables *)

const cdLeftPane :CellDef = (lType:CELL_WINDOW; pszClass:WC_LISTBOX; pszName:'List';
                             ulStyle:LS_NOADJUSTPOS or WS_VISIBLE; ulID:ID_LIST);

      cdRightPane:CellDef = (lType:CELL_WINDOW; pszClass:WC_MLE; pszName:'Sample Text';
                             ulStyle:MLS_BORDER or WS_VISIBLE; ulID:ID_MLE);

      rPanel     :CellDef = (lType:CELL_VSPLIT or CELL_SPLITBAR or CELL_SPLIT30x70;
                             pszClass:nil; pszName:'Subwindow';
                             ulStyle:WS_VISIBLE; ulID:ID_TOP; pPanel1:@cdLeftPane;
                             pPanel2:@cdRightPane; pClassProc:nil; pClientClassProc:nil);

      Panel1     :CellDef = (lType:CELL_WINDOW; pszClass:'StatusLine'; pszName:'';
                             ulStyle:WS_VISIBLE; ulID:ID_STATUS);

      mainClient :CellDef = (lType:CELL_HSPLIT or CELL_FIXED or CELL_SIZE1; pszClass:nil;
                             pszName:'Status Line Sample'; ulStyle:FCF_TITLEBAR or FCF_SYSMENU or
                             FCF_MENU or FCF_MINMAX or FCF_TASKLIST or FCF_SIZEBORDER; ulID:MAIN_FRAME;
                             pPanel1:@Panel1; pPanel2:@rPanel;
                             pClassProc:nil;                  // Frame subclass proc
                             pClientClassProc:MainClientProc; // Client subclass proc
                             lSize:20                         // Status line hight
                            );

      mainItems:array [0..17] of longint=(
                             IDB_FILENEW , IDB_FILEOPEN, IDB_FILESAVE, IDB_FILSAVAS, TB_SEPARATOR,
                             IDB_EXIT    , TB_SEPARATOR, IDB_EDITCOPY, IDB_EDITCUT , IDB_EDITFIND,
                             IDB_EDITFNNX, IDB_EDITPAST, IDB_EDITREPL, IDB_EDITUNDO, TB_SEPARATOR,
                             IDB_HELP    , IDB_ABOUT   , 0);

      mainTb:TbDef         = (lType:TB_VERTICAL or TB_ATTACHED_TP or TB_BUBBLE; ulID:ID_TOOLBAR;
                             tbItems:@mainItems);

const MLE_INDEX = 0;

function OKMsgBox(pszText:pchar):longint;
begin
  result:=WinMessageBox(HWND_DESKTOP, HWND_DESKTOP, pszText, 'Cell Demo', 0,
    MB_OK or MB_INFORMATION or MB_APPLMODAL);
end;

const CVis:boolean=true;

function MainClientProc(Window: HWnd; Msg: ULong; Mp1,Mp2: MParam): MResult;
var pWCtlData:PWindowCellCtlData;
begin
  pWCtlData:=PWindowCellCtlData(WinQueryWindowULong(Window,QWL_USER));
  result   :=0;
  case msg of
    WM_COMMAND:begin
        case SHORT1FROMMP(mp1) of
          IDB_EXIT:begin
              WinPostMsg(Window, WM_QUIT, 0, 0);
              exit;
            end;
          IDB_FILENEW:begin
              CVis:=not CVis;
              ShowCell(hwndFrame,ID_LIST,CVis);
              exit;
            end;
        end;
      end;
    WM_CLOSE:begin
        WinPostMsg(Window, WM_QUIT, 0, 0);
        exit;
      end;
  end;
  if pWCtlData<>nil then
    result:=pWCtlData^.pOldProc(Window, msg, mp1, mp2)
  else
    result:=WinDefWindowProc(Window, msg, mp1, mp2);
end;

function StatusLineProc(Window: HWnd; Msg: ULong; Mp1,Mp2: MParam): MResult; cdecl;
var hpsPaint :HPS;
    rclPaint :RECTL;
    ptlWork  :POINTL;
begin
  result:=0;
  case msg of
    WM_PAINT:begin
        hpsPaint:= WinBeginPaint(Window, 0, nil);
        WinQueryWindowRect(Window, rclPaint);

        WinFillRect(hpsPaint, rclPaint, CLR_PALEGRAY);

        GpiSetColor(hpsPaint, CLR_BLACK);

        ptlWork.x:= rclPaint.xLeft      ;
        ptlWork.y:= rclPaint.yBottom    ;
        GpiMove(hpsPaint, ptlWork);
        ptlWork.y:= rclPaint.yTop    - 2;
        GpiLine(hpsPaint, ptlWork);
        ptlWork.x:= rclPaint.xRight  - 1;
        GpiLine(hpsPaint, ptlWork);

        GpiSetColor(hpsPaint,CLR_WHITE);

        ptlWork.y:= rclPaint.yBottom    ;
        GpiLine(hpsPaint, ptlWork);
        ptlWork.x:= rclPaint.xLeft      ;
        GpiLine(hpsPaint, ptlWork);

        dec(rclPaint.yTop,3);
        inc(rclPaint.yBottom);
        dec(rclPaint.xRight,2);
        inc(rclPaint.xLeft);

        WinDrawText(hpsPaint, -1, 'Status message', rclPaint, CLR_BLACK, 0, DT_LEFT or DT_VCENTER);
        WinEndPaint(hpsPaint);
        exit;
      end;
  end;
  result:=WinDefWindowProc(Window, msg, mp1, mp2);
end;

var Anchor   :HAB;
    mq       :HMQ;
    msg      :QMSG;
    hwndTb   :HWND;
    hwndTmp  :HWND;
    swp      :os2pmapi.SWP;
    hwndSubframe:HWND;
const
    lColor   :LONG=CLR_PALEGRAY;
    cFontMy  :pchar='8.Helv';
begin
  Anchor:=WinInitialize(0);
  if Anchor=0 then halt(-1);

  mq:=WinCreateMsgQueue(Anchor, 0);

  if mq=0 then
  begin
    WinTerminate(Anchor);
    halt(-2);
  end;

  ToolkitInit(Anchor);

  WinRegisterClass(Anchor, 'StatusLine', StatusLineProc, CS_SIZEREDRAW, sizeof(ULONG));

  WinQueryWindowPos(HWND_DESKTOP, swp);

  hwndFrame:=CreateCell(mainClient, HWND_DESKTOP, 0);

  if hwndFrame<>0 then
  begin
    hwndSubframe:=CellWindowFromID(hwndFrame, ID_LPANE);

    WinSetWindowPos(hwndFrame, NULLHANDLE, swp.x + swp.cx div 8,
      swp.y + swp.cy div 8, (swp.cx div 4) * 3, (swp.cy div 4) * 3,
        SWP_ACTIVATE or SWP_MOVE or SWP_SIZE or SWP_SHOW);

    CreateToolbar(hwndFrame,mainTb);

    (* Set status line font *)

    hwndTmp:=CellWindowFromID(hwndFrame, ID_STATUS);

    WinSetPresParam(hwndTmp, PP_FONTNAMESIZE, strlen(cFontMy)+1, cFontMy);

    (* Set MLE color *)

    hwndTmp:= CellWindowFromID(hwndFrame, ID_MLE);

    WinSendMsg(hwndTmp, MLM_SETBACKCOLOR, CLR_PALEGRAY, MLE_INDEX);

    (* Set list color *)

    hwndTmp:= CellWindowFromID(hwndFrame, ID_LIST);

    WinSetPresParam(hwndTmp, PP_BACKGROUNDCOLORINDEX, sizeof(lColor), @lColor);

    // -------------------------------
    while WinGetMsg(Anchor,msg,0,0,0) do WinDispatchMsg(Anchor,msg);
    // -------------------------------
    WinDestroyWindow(hwndFrame);
  end;

  WinDestroyMsgQueue(mq);
  WinTerminate(Anchor);
end.


