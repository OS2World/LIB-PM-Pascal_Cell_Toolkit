(*
** Module   :NBSAMPLE.C
** Abstract :
**
** Copyright (C) Sergey I. Yevtushenko
** Log: Fri  19/02/1998     Created
**
*)
uses os2def,os2pmapi,cell,strings;

{$PMTYPE PM}

{$I multibar.inc}

{$R nbsample.res}

(* Local procedures *)

function MainClientProc(Window: HWnd; Msg: ULong; Mp1,Mp2: MParam): MResult; cdecl; forward;

(* Static Variables *)

const BKS_TABBEDDIALOG = $00000800;  (* Tabbed dialog         *)
      BKS_MAJORTABTOP  = $00000040;  (* Major tabs top        *)

const cdLeftPane :CellDef = (lType:CELL_WINDOW; pszClass:WC_LISTBOX; pszName:'List';
                             ulStyle:LS_NOADJUSTPOS or WS_VISIBLE; ulID:ID_LPANE);

      cdRightPane:CellDef = (lType:CELL_WINDOW; pszClass:WC_MLE; pszName:'Sample Text';
                             ulStyle:MLS_BORDER or WS_VISIBLE; ulID:ID_RPANE);

      nbClient   :CellDef = (lType:CELL_VSPLIT or CELL_SPLITBAR or CELL_SPLIT40x60;
                             pszClass:nil; pszName:'Notebook page';
                             ulStyle:0; ulID:MAIN_FRAME; pPanel1:@cdLeftPane;
                             pPanel2:@cdRightPane; pClassProc:nil; pClientClassProc:nil);

      nbPanel:CellDef     = (lType:CELL_WINDOW; pszClass:WC_NOTEBOOK; pszName:'';
                             ulStyle:WS_VISIBLE or BKS_TABBEDDIALOG or BKS_MAJORTABTOP;
                             ulID:ID_NOTEBOOK);

      mainFrame:CellDef   = (lType:CELL_HSPLIT; pszClass:nil; pszName:'Notebook Sample';
                             ulStyle:FCF_TITLEBAR or FCF_SYSMENU or FCF_MENU or FCF_MINMAX or
                             FCF_TASKLIST or FCF_SIZEBORDER; ulID:MAIN_FRAME; pPanel1:@nbPanel;
                             pPanel2:nil; pClassProc:nil; pClientClassProc:MainClientProc);

      mainItems:array [0..18] of longint=(
                             IDB_FILENEW , IDB_FILEOPEN, IDB_FILESAVE, IDB_FILSAVAS, TB_SEPARATOR,
                             IDB_EXIT    , TB_SEPARATOR, IDB_EDITCOPY, IDB_EDITCUT , IDB_EDITPAST,
                             IDB_EDITUNDO, TB_SEPARATOR, IDB_EDITFIND, IDB_EDITFNNX, IDB_EDITREPL,
                             TB_SEPARATOR, IDB_HELP    , IDB_ABOUT   , 0);

      mainTb:TbDef         = (lType:TB_ATTACHED_TP or TB_BUBBLE; ulID:ID_TOOLBAR; tbItems:@mainItems);

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

var Anchor   :HAB;
    mq       :HMQ;
    msg      :QMSG;
    hwndFrame:HWND;
    swp      :os2pmapi.SWP;
    ulPageId :longint;
    hwndList :HWND;
    hwndTb   :HWND;
    hwndNb   :HWND;
    hwndPage :HWND;
    cText    :array [byte] of char;
    cTPos    :pchar;
    ii,jj    :longint;
const
    ppNbFont :pchar='9.WarpSans';
    cPage    :pchar='Page ';
    cListItem:pchar='List Item ';
    cTab1    :pchar='Source';
    cTab2    :pchar='Optimize';
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

  WinQueryWindowPos(HWND_DESKTOP, swp);

  hwndFrame:=CreateCell(mainFrame, HWND_DESKTOP, 0);

  if hwndFrame<>0 then
  begin
    hwndNb:=CellWindowFromID(hwndFrame, ID_NOTEBOOK);
    WinSetPresParam(hwndNb,PP_FONTNAMESIZE,sizeof(ppNbFont),ppNbFont);

    for ii:=0 to 1 do
    begin
      ulPageId:=WinSendMsg(hwndNb, BKM_INSERTPAGE, 0,
        MPFROM2SHORT(BKA_MAJOR or BKA_AUTOPAGESIZE,BKA_LAST));
      strcopy(cText,cPage);
      GenResIDStr(cText+sizeof(cPage)-1,ii+1);

      if ii=0 then
        WinSendMsg(hwndNb, BKM_SETTABTEXT, ulPageId, LONG(cTab1))
      else
        WinSendMsg(hwndNb, BKM_SETTABTEXT, ulPageId, LONG(cTab2));

      hwndPage:=CreateCell(nbClient,hwndNb,hwndNb);
      hwndList:=CellWindowFromID(hwndPage,ID_LPANE);

      for jj:=0 to 14 do
      begin
        strcopy(cText, cListItem);
        cTPos:=cText;
        inc(cTPos,sizeof(cListItem));
        GenResIDStr(cTPos,jj+1);
        WinSendMsg(hwndList, LM_INSERTITEM, LIT_END, LONG(@cText));
      end;

      WinSendMsg(hwndNb, BKM_SETPAGEWINDOWHWND, ulPageId, hwndPage);
    end;
    WinSetWindowPos(hwndFrame, NULLHANDLE, swp.x+swp.cx div 8, swp.y+swp.cy div 8,
      (swp.cx div 4)* 3, (swp.cy div 4)*3, SWP_ACTIVATE or SWP_MOVE or SWP_SIZE or SWP_SHOW);
    CreateToolbar(hwndFrame,mainTb);

    // -------------------------------
    while WinGetMsg(Anchor,msg,0,0,0) do WinDispatchMsg(Anchor,msg);
    // -------------------------------
    WinDestroyWindow(hwndFrame);
  end;

  WinDestroyMsgQueue(mq);
  WinTerminate(Anchor);
end.

