create or replace package pkg_Barcode is

  -- Author  : VALR
  -- Created : 11/02/2013 07:53:07
  -- Purpose : Barcode Encoding
  -- Version : 1.0.2  18.07.2014
/* 
   1.0.2  Add function Code128_CIA
*/
  
  function CheckDigit(p_vCodice in varchar2) return varchar2;


  function EAN_font(p_vCodice   in varchar2) return varchar2;

  function Code128(p_vCode      in varchar2) return varchar2;
  function Code128_CIA(p_vCode  in varchar2) return varchar2;

  procedure Font_CIA_EAN;     /* use CIA Ean font (Default)*/
  procedure Font_CODE_EAN13;  /* use Ean13.ttf  font*/ 

end pkg_Barcode;

/* Example:
   Default font is CIA_EAN, if you wont to use ean13.ttf 
   you must initialize it with procedure Font_CODE_EAN13;

   pkg_Barcode.Font_CODE_EAN13;                     -- Initilize font 
   v_vEan := pkg_Barcode.EAN_font('800112000277');       
*/



create or replace package body pkg_Barcode is

-- EAN, encodig Tables
  g_vTab0 varchar2(10);
  g_vTabA varchar2(10);
  g_vTabB varchar2(10);
  g_vTabC varchar2(10);
  g_vCent varchar2(1);
  g_vEnd  varchar2(1);
  g_vExtC varchar2(1);
  g_vExtS varchar2(1);

procedure Font_CIA_EAN is
begin
  g_vTab0:='0123456789';
  g_vTabA:='ABCDEFGHIJ';
  g_vTabB:='abcdefghij';
  g_vTabC:='KLMNOPQRST';
  g_vCent:='k';
  g_vEnd :='l';
  g_vExtC:='#';
  g_vExtS:='$';
end;
  
procedure Font_CODE_EAN13 is
begin
  g_vTab0:='0123456789';
  g_vTabA:='ABCDEFGHIJ';
  g_vTabB:='KLMNOPQRST';
  g_vTabC:='abcdefghij';
  g_vCent:='*';
  g_vEnd :='+';
  g_vExtC:='[';
  g_vExtS:='\';
end;

function GetTab(v_vTab in varchar2, v_vCodice in varchar2, v_nPos in number) return varchar2 is
  i number(2);
begin
  i:=to_number(substr(v_vCodice, v_nPos, 1) )+1;
  case v_vTab
    when '0' then return(substr(g_vTab0, i, 1));
    when 'A' then return(substr(g_vTabA, i, 1));
    when 'B' then return(substr(g_vTabB, i,1));
    when 'C' then return(substr(g_vTabC, i,1));
    else
      Raise_application_error(-20000, 'EAN unknown Table');
  end case;
end;


FUNCTION CheckDigit(p_vCodice IN VARCHAR2) RETURN varchar2 IS
  /* Tested only for EAN 13 and EAN 8 */
  wk_i    NUMBER:= 12;
  wk_pari NUMBER:= 0;
  wk_disp NUMBER:= 0;
  wk_tota NUMBER:= 0;
  codice_ean varchar2(13);
BEGIN

   case length(p_vCodice)
     when 13 then
       codice_ean:= substr(p_vCodice,1,12)||'0';
     when 12 then
       codice_ean:= p_vCodice||'0';
     when 8 then
       codice_ean:= substr(p_vCodice,1,7)||'0';
     when 7 then
       codice_ean:= p_vCodice||'0';  
     else
       Raise_application_error(-20000, 'EAN length not allowed');
   end case;
   codice_ean:=LPAD(codice_ean,13,'0');
   
   WHILE wk_i > 0 LOOP
      wk_pari := wk_pari + TO_NUMBER(SUBSTR(codice_ean,wk_i,1));
      wk_i := wk_i - 1;
      wk_disp := wk_disp + TO_NUMBER(SUBSTR(codice_ean,wk_i,1));
      wk_i := wk_i - 1;
   END LOOP ;
   --
   wk_tota := wk_pari * 3 + wk_disp;
   --
   RETURN( lpad(CEIL(wk_tota/10)*10 - wk_tota,1,'0')  );
END;

-- PL/SQL
function EAN_font(p_vCodice in varchar2) return varchar2 is
/*Parameters  : 8/12/13 char ( check is calculated x 12 char)
  Return: string encoded for EAN13.TTF
             : Empty string when parameters are not valid 
  EAN13.TTF  : 48- 57 Tavola 0 :Primo carattere preceduto dalla Start Stripe 101
             : 66- 75 Table A
             : 76- 85 Table B
             : 98-107 Table C
             :108-117 Table D numbers without bars 
             : * Central Stripe 01010
             : + End Stripe     101
             : : Start Stripe   101 (not necessary using set 48-57)
             : [ Start Extension
             : \ Separator Extension
     *+0123456789:ABCDEFGHIJKLMNOPQRST[\abcdefghijklmnopqrst       
                  
  */
  v_vCodice   varchar2(20);
  v_nLen      NUMBER;
  v_nI        number;
  v_vC        varchar2(1);     -- Single char
  v_nFirst    Number(1);
  v_vBarcode  varchar2(20);
  v_bTableA   Boolean;

begin
  if g_vTab0 is null then
    Raise_application_error(-20000, 'Font is not Initialized ');
  end if;
  
-- Il length is 13, remove Check Digit
  v_nLen := length(p_vCodice);
  CASE WHEN v_nLen not in (7,8,12,13) THEN
    RETURN(null);  -- Length not allowed, end immediatly
  ELSE
    -- Only numbers ?
    FOR v_nI in 1..v_nLen LOOP
      v_vC := substr(p_vCodice, v_nI, 1);
      IF v_vC < '0' or v_vC > '9' THEN
        RETURN(null);        -- Non numeric char detected. End imediatly
      END IF;
    END LOOP;
    if v_nLen in (8, 13) THEN  
      -- detect check digit
      v_vCodice:=p_vCodice;
    else
      -- Calculate check Digit
      v_vCodice := p_vCodice || CheckDigit(p_vCodice); -- Append check Digit 
      v_nLen := v_nLen+1;
    end if;
    
  END CASE;
  
  ----------------------------------------------------
  -- START Sting for printing                 --
  ----------------------------------------------------
  
  v_nFirst := to_number(substr(v_vCodice, 1, 1));
  -- First number is from table 0
  v_vBarcode :=  GetTab('0', v_vCodice, 1);
  -- The second always from table A
  v_vBarcode := v_vBarcode || GetTab('A', v_vCodice, 2);
  if v_nLen = 8 then
    -- EAN8, 3 and 4 also from Table A
    v_vBarcode := v_vBarcode||GetTab('A', v_vCodice, 3);
    v_vBarcode := v_vBarcode||GetTab('A', v_vCodice, 4);
  else
    -- The second always from table A
    For v_nI in 3..7 loop
      v_bTableA := False;
      CASE v_nI
        WHEN 3 THEN
          v_bTableA := (instr('0123',v_nFirst)>0);
        WHEN 4 then
          v_bTableA := (instr('0478',v_nFirst)>0);
        WHEN 5 THEN
          v_bTableA := (instr('01459',v_nFirst)>0);
        WHEN 6 THEN
          v_bTableA := (instr('02567',v_nFirst)>0);
        WHEN 7 THEN
          v_bTableA := (instr('03689',v_nFirst)>0);
      END CASE;
    
      If v_bTableA Then               --Table A
        v_vBarcode := v_vBarcode || GetTab('A', v_vCodice,v_nI);
      Else                            --Table B
        v_vBarcode := v_vBarcode || GetTab('B', v_vCodice,v_nI);
      End If;
    END LOOP;
  END IF;
  
  v_vBarcode := v_vBarcode ||g_vCent;     --Central separator 01010
  v_nFirst := 8;
  if v_nLen = 8 then
    v_nFirst := 5;
  end if;  
  For v_nI in v_nFirst..v_nLen LOOP   --Table C 
    v_vBarcode := v_vBarcode || GetTab('C', v_vCodice,v_nI);
  END LOOP;
  v_vBarcode := v_vBarcode || g_vEnd;     --End Marker
  return(v_vBarcode);
end;

function checkNumeric(p_vCode in varchar2, p_nIndex in integer, p_nMini in integer) return boolean is
begin
  if length(substr(p_vCode, p_nIndex, p_nMini)) < p_nMini then
    return false;  
  end if;
  if nvl(length(trim(translate(substr(p_vCode, p_nIndex, p_nMini),'0123456789',' '))),0)=0 then
    return true;
  else
    return false;  
  end if;
end;

function Code128(p_vCode in varchar2) return varchar2 is
  v_nIndex    integer;       /* Progress index into code string */
  v_nChecksum number;        
  v_nMini     integer;       /* numero char at end of code */
  v_nDummy    integer;       /
  v_bTableB   BOOLEAN;       /* Indica l'uso della table B del code 128 */
  v_vCode128  varchar2(1000);/* code 128 risultante */
  v_nLen      integer;       /* lunghezza del codice */
  v_nChr      integer; 
  
  -- You can see documentatio at this link
  -- http://grandzebu.net/informatique/codbar-en/code128.htm
  -- this is link for forn download   
  -- http://grandzebu.net/informatique/codbar/code128.ttf 

  -- This funzione correct some error
  -- VALR 30.05.2014    - V 1.00.00
begin 
  v_vCode128 := '';
  v_nLen := length(p_vCode);
  If (v_nLen>0) Then
    For v_nIndex in 1 .. v_nLen loop
      v_nChr := ASCII(SUBSTR(p_vCode, v_nIndex, 1));
      if v_nChr < 32 or v_nChr > 126 then   
        return null;  -- Code not found
      end if;    
    end loop;

    v_bTableB:= True;
    v_nIndex:= 1;
    WHILE v_nIndex <= v_nLen LOOP
      If v_bTableB Then
      -- Test convenience of table C, 
      -- more than 4 chars at begin or end or 6 numbers 
        IF ((v_nIndex = 1) OR (v_nIndex+3 = v_nLen)) THEN 
          v_nMini := 4;  -- For firts o last 4 use 4 
        ELSE
          v_nMini := 6; 
        END IF;
        If checkNumeric(p_vCode, v_nIndex, v_nMini) then -- Use Table C
          If v_nIndex = 1 Then -- Start with Table C
            v_vCode128 := chr(210);
          Else -- Switch to Table C
            v_vCode128 := v_vCode128 || Chr(204);
          End If;
          v_bTableB := False;
        Else
          If v_nIndex = 1 Then -- Begin with Table B
            v_vCode128 := Chr(209); 
          End If;
        End If;
      End if;
        
      If v_bTableB=FALSE Then
      -- TableC: encode 2 numbers at time
        v_nMini:= 2;
        if checkNumeric(p_vCode, v_nIndex, v_nMini)   then
          v_nDummy := to_number(SUBSTR(p_vCode, v_nIndex, 2));
          v_vCode128 := v_vCode128 || CHR(v_nDummy + case when v_nDummy <95 then 32 else 105 end);
          v_nIndex := v_nIndex +2;
        Else -- Switch to TableB
          v_vCode128 := v_vCode128 || CHR(205);
          v_bTableB := TRUE;
        End If;
      End If;
      If v_btableB Then
        v_vCode128 :=  v_vCode128 || substr(p_vCode, v_nIndex, 1);
        v_nIndex := v_nIndex + 1;
      End If;
    end Loop;

    -- Calculate checksum
    v_nLen:=LENGTH(v_vCode128);
    FOR v_nIndex IN 1 .. v_nLen LOOP
      v_nDummy:= ASCII(SUBSTR(v_vCode128, v_nIndex, 1));
      v_nDummy:=v_nDummy-case when v_nDummy < 127 then 32 else 105 end;
      if v_nIndex = 1 then
        v_nChecksum := v_nDummy;
      end if;
      v_nChecksum := mod(v_nChecksum + (v_nIndex-1) * v_nDummy, 103);
    end loop;
    v_nChecksum := v_nChecksum + case when v_nChecksum < 95 THEN 32 else 105 end;
    return v_vCode128||Chr(v_nchecksum)||Chr(211);
  end if;
  
end;


function Code128_CIA(p_vCode in varchar2) return varchar2 is
  v_vCode128 varchar2(500);        -- Code128
  v_vResult  varchar2(4000);
  v_nN pls_integer;
  v_nL pls_integer;
  v_nP pls_integer;
  v_vC varchar2(1);
  
  k_vCode128 constant varchar2(108) :=' !"#$%&''()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~ÈÉÊËÌÍÎÏÐÑÒÓÔ';
  k_vCia1    constant varchar2(108) :='?CC448559BBE155266DBB@DIHLLIMM??F088199>EE11922:J>E@@@HHNIIOKBT0044<<1155==GBRG;044377PSS?AQ00833PP23HP>>>#?';  
  k_vCia2    constant varchar2(108) :='hZgishepdepdl^khZgc^kdV]hZgdVc[rYt[rqWoqWo_u][rYYu]Wo][rYWoUUwUjz\yZgfxXwVccXUVUnamdVcdVc`YYbv`WoWo`]`]xfl§§';
begin
  
  v_vCode128:=Code128( p_vCode );  -- Calculate encoded string for font code128
  v_nL:=length(v_vCode128);        -- Transcode to font CIA128
  for v_nN in 1..v_nL 
  loop
    v_vC := substr(v_vCode128,v_nN,1);
    v_nP := instr(k_vCode128, v_vC);
    v_vResult:=v_vResult||substr(k_vCia1,v_nP,1)||substr(k_vCia2,v_nP,1);
  end loop;
  v_vResult:=trim(replace(v_vResult,'§',''));
  return v_vResult;
end;  

begin
  -- Initialization
  Font_CIA_EAN;
end pkg_Barcode;
pkg_barcode.sql
Visualizzazione di pkg_barcode.sql.
