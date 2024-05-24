-- Created on 25/06/2014 by VALR 
declare 

        i              INTEGER;
        v_vFileName    VARCHAR2(255);
        v_vOddColor    VARCHAR2(6) := 'd0d0d0';
        v_vHeadColor   VARCHAR2(6) := 'e0ffff';
        v_vOraDir      VARCHAR2(50) := 'PDF';
        v_vPageProc    VARCHAR2(32000);
        r_Fmt  as_pdf3_v5.tp_columns:=as_pdf3_v5.tp_columns();
        v_vSQL varchar2(4000);
begin
  v_vFileName    := 'Test_as_pf3_v5.pdf';
  -- FORMATTAZZIONE FOGLIO
  as_pdf3_v5.init;
  as_pdf3_v5.set_page_format('A4');
  as_pdf3_v5.set_page_orientation('P');
  as_pdf3_v5.set_margins(30, 10, 15, 10, 'mm');
     
  -- Definisco Intestazione e piede Pagina
  v_vPageProc := q'[
  begin
    §.set_font('helvetica', 'B', 10 );
    §.put_txt('mm',  5, 5, 'Valerio Rossetti');
    §.put_txt('mm',  90, 5, 'Data: ');
    §.set_font('helvetica', 'N', 10);
    §.put_txt('mm', 115,5, ']'||to_char(sysdate,'dd/mm/yy')||q'[');    
    §.put_txt('mm', 175,5, 'Pagina #PAGE_NR# di #PAGE_COUNT#');
  end;
  ]';
     
  as_pdf3_v5.set_page_proc(v_vPageProc);
  
  --Se vuoi usare dei font per i barcode    
  --as_pdf3_v5.load_ttf_font('PDF', 'ean13.ttf', 'CID', TRUE);

    -- Definizione dei formati
    begin
      r_fmt.extend(9);
      i:=1; -- (riga di rottura
      r_fmt(i).colWidth:=25;
      r_fmt(i).colLabel:='cod mkt';
      r_fmt(i).hFontStyle:='B';
      r_fmt(i).hFontSize:=10;
      r_fmt(i).hAlignment:='C';
      r_fmt(i).hAlignVert:='T';
      r_fmt(i).tAlignment:='L';
      r_fmt(i).tAlignVert:='B';
      r_fmt(i).tFontSize:=8;
      r_fmt(i).tCHeight := 7;
      r_fmt(i).hCHeight := 7;
      r_fmt(i).cellRow := 1;
      
      i:=i+1;--2
      r_fmt(i).colWidth:=20;
      r_fmt(i).colLabel:='cod_art';
      r_fmt(i).hFontStyle:='B';
      r_fmt(i).hFontSize:=10;
      r_fmt(i).hAlignment:='R';
      r_fmt(i).hAlignVert:='T';
      r_fmt(i).tAlignVert:='T';
      --r_fmt(i).offsetX := 0;
      r_fmt(i).tCHeight := 7;
      r_fmt(i).hCHeight := 7;
      
      i:=i+1;--3
      r_fmt(i).colWidth:=22;
      r_fmt(i).colLabel:='pz imb';
      r_fmt(i).hFontStyle:='B';
      r_fmt(i).hFontSize:=10;
      r_fmt(i).hAlignment:='C';
      r_fmt(i).hAlignVert:='T';
      r_fmt(i).tAlignment:='R';
      r_fmt(i).tAlignVert:='M';
      
      i:=i+1;--4
      r_fmt(i).colWidth:=12;
      r_fmt(i).colLabel:='udm V';
      r_fmt(i).hFontStyle:='B';
      r_fmt(i).hFontSize:=10;
      r_fmt(i).hAlignment:='C';
      r_fmt(i).hAlignVert:='T';
      r_fmt(i).tAlignment:='C';
      r_fmt(i).tAlignVert:='B';
      r_fmt(i).tBorder := as_pdf3_v5.BorderType('TB');
      
      i:=i+1;--5
      r_fmt(i).colWidth:=15;
      r_fmt(i).colLabel:='udm Lt';
      r_fmt(i).hFontStyle:='B';
      r_fmt(i).hFontSize:=10;
      r_fmt(i).hAlignment:='C';
      r_fmt(i).hAlignVert:='T';
      r_fmt(i).tAlignment:='C';
      r_fmt(i).tAlignVert:='B';
      
      i:=i+1;--6
      r_fmt(i).colWidth:=20;
      r_fmt(i).colLabel:='prz. vend.';
      r_fmt(i).hFontStyle:='B';
      r_fmt(i).hFontSize:=10;
      r_fmt(i).hAlignment:='C';
      r_fmt(i).hAlignVert:='T';
      r_fmt(i).tAlignment:='R';
      r_fmt(i).tAlignVert:='B';
      i:=i+1;--7
      r_fmt(i).colWidth:=20;
      r_fmt(i).colLabel:='prz. costo.';
      r_fmt(i).hFontStyle:='B';
      r_fmt(i).hFontSize:=10;
      r_fmt(i).hAlignment:='C';
      r_fmt(i).hAlignVert:='T';
      r_fmt(i).tAlignment:='R';
      r_fmt(i).tAlignVert:='B';
      i:=i+1;--8
      r_fmt(i).colWidth:=16;
      r_fmt(i).colLabel:='margine';
      r_fmt(i).hFontStyle:='B';
      r_fmt(i).hFontSize:=10;
      r_fmt(i).hAlignment:='C';
      r_fmt(i).hAlignVert:='T';
      r_fmt(i).tAlignment:='R';
      r_fmt(i).tAlignVert:='B';
      r_fmt(i).tBorder := 15;
      i:=i+1;--9
      r_fmt(i).colWidth:=150;
      r_fmt(i).colLabel:='des.prodotto';
      r_fmt(i).hFontStyle:='B';
      r_fmt(i).hFontSize:=10;
      r_fmt(i).hAlignment:='L';
      r_fmt(i).hAlignVert:='T';
      r_fmt(i).hCHeight := 8;
      r_fmt(i).tAlignment:='L';
      r_fmt(i).tAlignVert:='C';
      r_fmt(i).tFontSize:=8;
      r_fmt(i).offsetX := 0;
      r_fmt(i).tCHeight := 8;
      r_fmt(i).cellRow:=2;
      r_fmt(i).tBorder := as_pdf3_v5.BorderType('LRBT');

    end;

     v_vSQL := q'[
SELECT cod_mkt,
       c_art, 
       pezzi_imb,
       udm_vendita,
       udm_listino,
       prz_vendita,
       prz_vendita*.8 prz_costo,
       prz_vendita*.2 margine,
       descrizione
from (       
SELECT case when rownum <5 then '5201001' else '5201003' end cod_mkt,
             rownum*1000+rownum*124 c_art, 
             (trunc(rownum/3)+1)*4  pezzi_imb,
             'N'  udm_vendita,
             'KG' udm_listino,
             round(dbms_random.value(40,2),2) prz_vendita,
             round(dbms_random.value(8,2),2) margine,
             'ARTICOLO '||to_char(rownum*1000+rownum*124) descrizione
        FROM DUAL d CONNECT BY ROWNUM <= 10
)
order by 1
   ]';
   dbms_output.put_line(v_vSQL);
         
   as_pdf3_v5.query2table(v_vSQL,
     r_fmt,
     as_pdf3_v5.tp_colors('000000',v_vHeadColor,'000000',
                          '000000','ffffff','000000',
                          '000000',v_vOddColor,'000000'),
     15,15, 'mm',0,1
     );
         
    as_pdf3_v5.save_pdf(v_vOraDir, v_vFileName, TRUE);
  END;
