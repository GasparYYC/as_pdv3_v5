CREATE OR REPLACE PACKAGE PKG_SENDMAIL IS

  -- Author  : VALR
  -- Created : 26/03/2014 15:37:20
  -- Purpose : Invio Mail SMTP
  --           21/09/2016 aggiunto supporto HTML
  -- Public type declarations

-- Tipi definiti per eventuali evoluzioni con Attachment Multipli di tipo File o BLOB
   TYPE BLOB_ATTACH IS RECORD (
     AttcahName VARCHAR2(100),
     AttachBLOB BLOB
   );
   TYPE BLOB_ATTACH_LIST IS TABLE OF BLOB_ATTACH;
   
   TYPE ATTACHMENTS_LIST IS TABLE OF VARCHAR2(4000);

  -- Dichiarazioni di BASE
  -- Inizia una mail
  PROCEDURE mail_start(
    p_from    VARCHAR2,
    p_to      VARCHAR2 := NULL,
    p_cc      VARCHAR2 := NULL,
    p_bcc     VARCHAR2 := NULL,
    p_subject VARCHAR2,
    p_message VARCHAR2,
    p_html    VARCHAR2  := 'N');
  -- Aggiunge un allegato BLOB
  PROCEDURE mail_attach(
    p_attachName VARCHAR2,  -- Nome da assegnare al file allegato
    p_attachBlob BLOB    ,  -- blob
    p_attachType VARCHAR2 default 'Content-Type: application/octet-stream'
    );
  -- Aggiunge un allegato da filesystem  
  PROCEDURE mail_attach(
    p_attachFile VARCHAR2, -- Nome del file
    p_Directory  VARCHAR2,  -- Nome Directory Oracle 
    p_attachType VARCHAR2 default 'Content-Type: application/octet-stream'
    );
  -- Termina una mail
  PROCEDURE mail_end;

  -- Mail Senza Allegati (versione compatta)
  PROCEDURE Send_Mail(
    Sender     VARCHAR2,
    Recipients VARCHAR2,
    Subject    VARCHAR2,
    Message    VARCHAR2);
  PROCEDURE mail(
    p_from    VARCHAR2,
    p_to      VARCHAR2,
    p_subject VARCHAR2,
    p_message VARCHAR2,
    p_html    VARCHAR2 := 'N');

  -- Mail Senza Allegati
  PROCEDURE mail(
    p_from    VARCHAR2,
    p_to      VARCHAR2 := NULL,
    p_cc      VARCHAR2 := NULL,
    p_bcc     VARCHAR2 := NULL,
    p_subject VARCHAR2,
    p_message VARCHAR2,
    p_html    VARCHAR2 := 'N');
  PROCEDURE mail_cc(
    p_from    VARCHAR2,
    p_to      VARCHAR2 := NULL,
    p_cc      VARCHAR2 := NULL,
    p_bcc     VARCHAR2 := NULL,
    p_subject VARCHAR2,
    p_message VARCHAR2);

  -- Mail con Allegato BLOB    
  PROCEDURE mail(
    p_from       VARCHAR2,
    p_to         VARCHAR2 := NULL,
    p_cc         VARCHAR2 := NULL,
    p_bcc        VARCHAR2 := NULL,
    p_subject    VARCHAR2,
    p_message    VARCHAR2,
    p_attachName VARCHAR2,
    p_attachBlob BLOB,
    p_html       VARCHAR2 := 'N');
  PROCEDURE mail_blob(
    p_from       VARCHAR2,
    p_to         VARCHAR2 := NULL,
    p_cc         VARCHAR2 := NULL,
    p_bcc        VARCHAR2 := NULL,
    p_subject    VARCHAR2,
    p_message    VARCHAR2,
    p_attachName VARCHAR2,
    p_attachBlob BLOB);

  -- Mail con Allegato FILE da filesystem    
  PROCEDURE mail(
    p_from       VARCHAR2,
    p_to         VARCHAR2 := NULL,
    p_cc         VARCHAR2 := NULL,
    p_bcc        VARCHAR2 := NULL,
    p_subject    VARCHAR2,
    p_message    VARCHAR2,
    p_attachFile VARCHAR2,
    p_Directory  VARCHAR2,
    p_html       VARCHAR2 := 'N');
  PROCEDURE mail_file(
    p_from       VARCHAR2,
    p_to         VARCHAR2 := NULL,
    p_cc         VARCHAR2 := NULL,
    p_bcc        VARCHAR2 := NULL,
    p_subject    VARCHAR2,
    p_message    VARCHAR2,
    p_attachFile VARCHAR2,
    p_Directory  VARCHAR2);

/*-- Replica della vecchia SendMailJpkg
-- Accetta una lista di allegati di tipo filesystem
  FUNCTION exSendMailJPKG(
    Sender IN STRING,
    Recipient IN STRING,
    CcRecipient IN STRING,
    BccRecipient IN STRING,
    Subject IN STRING,
    Body IN STRING,
    Attachments IN ATTACHMENTS_LIST) RETURN NUMBER;
*/
  
END PKG_SENDMAIL;
/
CREATE OR REPLACE PACKAGE BODY PKG_SENDMAIL IS

  l_conn utl_smtp.connection;
  l_boundary VARCHAR2(32) := sys_guid();

/* Determina il content type da usare in funzione di p_vType
 1) se inizia con . è considerata estensione 
    content type è individuato nella tavola tab_ContentType
 2) se contiene / è un content type 
    verifica la presenza di Content-Type: all'inizio, se non c'è lo aggiunge
 3) negli altri casi è un estensione, 
    aggiungo il . e cerco nella tavola tab_ContentType   
 4) in ultima istanza uso 'Content-Type: application/octet-stream'
*/
Function ContentType(p_vType in varchar2) return varchar2 is
  v_vEstensione  varchar2(20);
  v_vReturn      varchar2(100);

  k_vCT      constant varchar2(14) := 'Content-Type: ';
  k_vDefault constant varchar2(40) := 'Content-Type: application/octet-stream';
begin
  if substr(p_vType,1,1)='.' then
  -- 1 inizia con . è un estensione file  
    v_vEstensione := lower(p_vType);
  elsif instr(p_vType,'/') > 0 then
    v_vEstensione:='.';
      
  -- 2 Contiene il carattere /  è un content type
    if substr(p_vType,1,length(k_vCT)) = k_vCT then
    --  inizia con Content-Type: lo uso com'è
      v_vReturn := p_vType;
    elsif instr(p_vType,':') = 0 then
    -- Manca Content-Type: lo aggiungo
      v_vReturn := k_vCT ||p_vType;
    else
    -- Anomalo
      v_vReturn := null;
      Raise_application_error(-20000, 'Verifica il content-type  ['||p_vType||']');
    end if;
  else
    v_vEstensione := '.'||lower(p_vType);
  end if;    
  if v_vEstensione != '.' then
    select nvl(min(mimetype),k_vDefault)
      into v_vReturn
      from TAB_MIMETYPE 
     where est = v_vEstensione;
  end if;
  return v_vReturn;
end; 
  
FUNCTION Get_Address(Addr_List IN OUT VARCHAR2) RETURN VARCHAR2 IS

  Addr VARCHAR2(256);
  I    PLS_INTEGER;

  FUNCTION Lookup_Unquoted_Char(Str IN VARCHAR2, Chrs IN VARCHAR2)
    RETURN PLS_INTEGER AS
    C            VARCHAR2(5);
    I            PLS_INTEGER;
    Len          PLS_INTEGER;
    Inside_Quote BOOLEAN;
  BEGIN
    Inside_Quote := FALSE;
    I            := 1;
    Len          := LENGTH(Str);
    WHILE (I <= Len) LOOP
      C := SUBSTR(Str, I, 1);
      IF (Inside_Quote) THEN
        IF (C = '"') THEN
          Inside_Quote := FALSE;
        ELSIF (C = '\') THEN
          I := I + 1; -- SKIP THE QUOTE CHARACTER
        END IF;
      ELSIF (C = '"') THEN
        Inside_Quote := TRUE;
      ELSIF (INSTR(Chrs, C) >= 1) THEN
        RETURN I;
      END IF;
      I := I + 1;
    END LOOP;
    RETURN 0;
  END;

BEGIN

  Addr_List := LTRIM(Addr_List);
  I         := Lookup_Unquoted_Char(Addr_List, ',;');
  IF (I >= 1) THEN
    Addr      := SUBSTR(Addr_List, 1, I - 1);
    Addr_List := SUBSTR(Addr_List, I + 1);
  ELSE
    Addr      := Addr_List;
    Addr_List := '';
  END IF;

  I := Lookup_Unquoted_Char(Addr, '<');
  IF (I >= 1) THEN
    Addr := SUBSTR(Addr, I + 1);
    I    := INSTR(Addr, '>');
    IF (I >= 1) THEN
      Addr := SUBSTR(Addr, 1, I - 1);
    END IF;
  END IF;

  RETURN Addr;
END;

  PROCEDURE mail_start(
    p_from    VARCHAR2,
    p_to      VARCHAR2 := NULL,
    p_cc      VARCHAR2 := NULL,
    p_bcc     VARCHAR2 := NULL,
    p_subject VARCHAR2,
    p_message VARCHAR2,
    p_html    VARCHAR2 := 'N'
    ) IS

    v_vSMTP_server VARCHAR2(100);
    v_vRecipients  VARCHAR2(32767);
    v_vFrom        VARCHAR2(200);
  BEGIN
    if instr( p_from,'@')=0 then
      v_vFrom := p_from||'@unicooptirreno.coop.it';
    else
      v_vFrom := p_from;
    end if;
      -- Connect
    SELECT case when instr(smtp_server,':')>0 then
           substr(smtp_server,1, instr(smtp_server,':')-1) else smtp_server end
      INTO v_vSMTP_server  
      FROM sys.v_smtp_server;

    IF coalesce(p_to, p_cc, p_bcc) IS NULL THEN -- Verifico che almeno un parametro dei 3 sia specificato 
      Raise_application_error(-20001, 'Specificare almeno uno dei parametri to/cc/bcc');
    END IF;

    l_conn := utl_smtp.open_connection( v_vSMTP_server );
    utl_smtp.helo( l_conn, 'vignale.lan' );
    utl_smtp.mail( l_conn, v_vFrom );
    
    IF p_to IS NOT NULL THEN
      v_vRecipients := p_to;
      WHILE (v_vRecipients IS NOT NULL) LOOP
        utl_smtp.rcpt(l_conn, Get_Address(v_vRecipients));
      END LOOP;
    END IF; 
    
    IF p_cc IS NOT NULL THEN
      v_vRecipients := p_Cc;
      WHILE (v_vRecipients IS NOT NULL) LOOP
        utl_smtp.rcpt(l_conn, Get_Address(v_vRecipients));
      END LOOP;
    END IF;
    
    IF p_Bcc IS NOT NULL THEN
      v_vRecipients := p_Bcc;
      WHILE (v_vRecipients IS NOT NULL) LOOP
        utl_smtp.rcpt(l_conn, Get_Address(v_vRecipients));
      END LOOP;
    END IF;

    utl_smtp.open_data(l_conn);
   
    -- Header
    utl_smtp.write_data( l_conn, 'From: ' || v_vFrom || utl_tcp.crlf );
    IF p_to IS NOT NULL THEN
      utl_smtp.write_data( l_conn, 'To: ' || p_to || utl_tcp.crlf );
    END IF; 
    IF p_cc IS NOT NULL THEN
      utl_smtp.write_data( l_conn, 'Cc: ' || p_Cc || utl_tcp.crlf );
    END IF;
    IF p_bcc IS NOT NULL THEN
      utl_smtp.write_data( l_conn, 'Bcc: ' || p_Bcc || utl_tcp.crlf );
    END IF;
    utl_smtp.write_data( l_conn, 'Subject: ' || p_subject || utl_tcp.crlf );
    utl_smtp.write_data( l_conn, 'MIME-Version: 1.0' || utl_tcp.crlf );
    utl_smtp.write_data( l_conn, 'Content-Type: multipart/mixed; '|| utl_tcp.crlf );
    utl_smtp.write_data( l_conn, ' boundary= "'||l_boundary||'"'||utl_tcp.crlf );
    utl_smtp.write_data( l_conn, utl_tcp.crlf );
   
    -- Body
    utl_smtp.write_data( l_conn, '--' || l_boundary || utl_tcp.crlf );
    IF p_html = 'S' THEN
      utl_smtp.write_data( l_conn, 'Content-Type: text/html;'||utl_tcp.crlf );
    ELSE
      utl_smtp.write_data( l_conn, 'Content-Type: text/plain;'||utl_tcp.crlf );
    END IF;
--    utl_smtp.write_data( l_conn, ' charset=US-ASCII' || utl_tcp.crlf );
    utl_smtp.write_data( l_conn, ' charset=iso-8859-1' || utl_tcp.crlf );
    utl_smtp.write_data( l_conn, utl_tcp.crlf );
    utl_smtp.write_data( l_conn, p_message || utl_tcp.crlf );
    utl_smtp.write_data( l_conn, utl_tcp.crlf );

  EXCEPTION
    -- smtp errors, close connection and reraise
    WHEN utl_smtp.transient_error OR
         utl_smtp.permanent_error THEN
      utl_smtp.quit( l_conn );
      RAISE;
  END;  

  PROCEDURE mail_attach(
    p_attachName VARCHAR2,  -- Nome del file
    p_attachBlob BLOB    ,  -- blob
    p_attachType VARCHAR2 default 'Content-Type: application/octet-stream'
    ) IS

    l_blob BLOB := to_blob('1');
    l_raw RAW(57);
    l_len INTEGER := 0;
    l_idx INTEGER := 1;
    l_buff_size INTEGER := 57;
    v_attachType varchar2(200);
  BEGIN
    v_attachType:=ContentType(p_attachType);
    l_blob := p_attachBlob;
    -- Attachment
    utl_smtp.write_data( l_conn, '--' || l_boundary || utl_tcp.crlf );
    utl_smtp.write_data( l_conn, v_attachType||utl_tcp.crlf );
    utl_smtp.write_data( l_conn, 'Content-Disposition: attachment; '||utl_tcp.crlf );
    utl_smtp.write_data( l_conn, ' filename="'||p_attachName||'"'||utl_tcp.crlf );
    utl_smtp.write_data( l_conn, 'Content-Transfer-Encoding: base64'||utl_tcp.crlf );
    utl_smtp.write_data( l_conn, utl_tcp.crlf );
   
    -- Legge il BLOB in blocchi da 57 byte ,
    -- li codifica in base64 e li scrive nel buffer della mail
    l_len := dbms_lob.getlength(l_blob);
    WHILE l_idx < l_len LOOP
      dbms_lob.read( l_blob, l_buff_size, l_idx, l_raw );
      utl_smtp.write_raw_data( l_conn, utl_encode.base64_encode(l_raw) );
      utl_smtp.write_data( l_conn, utl_tcp.crlf );
      l_idx := l_idx + l_buff_size;
    END LOOP;
    utl_smtp.write_data( l_conn, utl_tcp.crlf );
  END;  

  PROCEDURE mail_attach(
    p_attachFile VARCHAR2, -- Nome del file
    p_Directory  VARCHAR2, -- Nome Directory Oracle 
    p_attachType VARCHAR2 default 'Content-Type: application/octet-stream'
    ) IS

    myBlob  BLOB;
    src_loc BFILE;
  BEGIN
    -- Apro il file nella cartella e lo copio in un blob
    dbms_lob.CREATETEMPORARY(myBlob, TRUE);
    src_loc := BFILENAME(p_Directory, p_attachFile);
    DBMS_LOB.FILEOPEN(src_loc, DBMS_LOB.LOB_READONLY);
    DBMS_LOB.LOADFROMFILE(myblob, src_loc, DBMS_LOB.getLength(src_loc));
    DBMS_LOB.FILECLOSE(src_loc);
    -- Chiudo il file  

    mail_attach(p_attachFile, myBlob, p_attachType);
  END;

  PROCEDURE mail_end IS
  BEGIN
    -- Close Email
    utl_smtp.write_data( l_conn, '--'||l_boundary||'--'||utl_tcp.crlf );
    utl_smtp.write_data( l_conn, utl_tcp.crlf||'.'||utl_tcp.crlf );
    utl_smtp.close_data( l_conn );
    utl_smtp.quit( l_conn );

  EXCEPTION
    -- smtp errors, close connection and reraise
    WHEN utl_smtp.transient_error OR
         utl_smtp.permanent_error THEN
      utl_smtp.quit( l_conn );
      RAISE;
    
  END;

/*
-- Dichiarazione con NomeFile + Blob
PROCEDURE mail(
  p_from VARCHAR2,
  p_to VARCHAR2 := null,
  p_cc VARCHAR2 := null,
  p_bcc VARCHAR2 := null,
  p_subject VARCHAR2,
  p_message VARCHAR2,
  p_attachName VARCHAR2,
  p_attachBlob blob
  ) is

-- declare
  l_conn utl_smtp.connection;
  l_boundary VARCHAR2(32) := sys_guid();

  l_blob blob := to_blob('1');
  l_raw raw(57);
  l_len integer := 0;
  l_idx integer := 1;
  l_buff_size integer := 57;
begin
 
  -- Connect
  l_conn := utl_smtp.open_connection( 'servermail.vignale.lan' );
  utl_smtp.helo( l_conn, 'vignale.lan' );
  utl_smtp.mail( l_conn, p_from );
  if coalesce(p_to, p_cc, p_bcc) is null then -- Verifico che almeno un parametro dei 3 sia specificato 
    Raise_application_error(-20001, 'Specificare almeno uno dei parametri to/cc/bcc');
  end if;
  if p_to is not null then
    utl_smtp.rcpt( l_conn, p_to );
  end if; 
  if p_cc is not null then
    utl_smtp.rcpt( l_conn, p_Cc );
  end if;
  if p_bcc is not null then
    utl_smtp.rcpt( l_conn, p_Bcc );
  end if;

  utl_smtp.open_data(l_conn);
 
  -- Header
  utl_smtp.write_data( l_conn, 'From: ' || p_from || utl_tcp.crlf );
  if p_to is not null then
    utl_smtp.write_data( l_conn, 'To: ' || p_to || utl_tcp.crlf );
  end if; 
  if p_cc is not null then
    utl_smtp.write_data( l_conn, 'Cc: ' || p_Cc || utl_tcp.crlf );
  end if;
  if p_bcc is not null then
    utl_smtp.write_data( l_conn, 'Bcc: ' || p_Bcc || utl_tcp.crlf );
  end if;
  utl_smtp.write_data( l_conn, 'Subject: ' || p_subject || utl_tcp.crlf );
  utl_smtp.write_data( l_conn, 'MIME-Version: 1.0' || utl_tcp.crlf );
  utl_smtp.write_data( l_conn, 'Content-Type: multipart/mixed; '|| utl_tcp.crlf );
  utl_smtp.write_data( l_conn, ' boundary= "'||l_boundary||'"'||utl_tcp.crlf );
  utl_smtp.write_data( l_conn, utl_tcp.crlf );
 
  -- Body
  utl_smtp.write_data( l_conn, '--' || l_boundary || utl_tcp.crlf );
  utl_smtp.write_data( l_conn, 'Content-Type: text/plain;'||utl_tcp.crlf );
  utl_smtp.write_data( l_conn, ' charset=US-ASCII' || utl_tcp.crlf );
  utl_smtp.write_data( l_conn, utl_tcp.crlf );
  utl_smtp.write_data( l_conn, p_message || utl_tcp.crlf );
  utl_smtp.write_data( l_conn, utl_tcp.crlf );
 

-- ------------------------------------------------------ 
-- Questo blocco può essere ripetito per ogni allegato
-- ------------------------------------------------------
-- LOOP
    l_blob := p_attachBlob;
    -- Attachment
    utl_smtp.write_data( l_conn, '--' || l_boundary || utl_tcp.crlf );
    utl_smtp.write_data( l_conn, 'Content-Type: application/octet-stream'||utl_tcp.crlf );
    utl_smtp.write_data( l_conn, 'Content-Disposition: attachment; '||utl_tcp.crlf );
    utl_smtp.write_data( l_conn, ' filename="'||p_attachName||'"'||utl_tcp.crlf );
    utl_smtp.write_data( l_conn, 'Content-Transfer-Encoding: base64'||utl_tcp.crlf );
    utl_smtp.write_data( l_conn, utl_tcp.crlf );
 
    -- Legge il BLOB in blocchi da 57 byte ,
    -- li codifica in base64 e li scrive nel buffer della mail
    l_len := dbms_lob.getlength(l_blob);
    while l_idx < l_len loop
      dbms_lob.read( l_blob, l_buff_size, l_idx, l_raw );
      utl_smtp.write_raw_data( l_conn, utl_encode.base64_encode(l_raw) );
      utl_smtp.write_data( l_conn, utl_tcp.crlf );
      l_idx := l_idx + l_buff_size;
    end loop;
    utl_smtp.write_data( l_conn, utl_tcp.crlf );
-- END LOOP;
 
  -- Close Email
  utl_smtp.write_data( l_conn, '--'||l_boundary||'--'||utl_tcp.crlf );
  utl_smtp.write_data( l_conn, utl_tcp.crlf||'.'||utl_tcp.crlf );
  utl_smtp.close_data( l_conn );
  utl_smtp.quit( l_conn );
 
exception
  -- smtp errors, close connection and reraise
  when utl_smtp.transient_error or
       utl_smtp.permanent_error then
    utl_smtp.quit( l_conn );
    raise;
 
end;
*/

  -- Mail Senza Allegati (versione compatta)
  PROCEDURE mail(
    p_from VARCHAR2,
    p_to VARCHAR2,
    p_subject VARCHAR2,
    p_message VARCHAR2,
    p_html    VARCHAR2 := 'N'
    ) IS
  BEGIN
--    mail_start(p_from, p_to, NULL, NULL, p_subject, p_message);
    mail_start(p_from, p_to, NULL, NULL, p_subject, p_message,p_html);    
    mail_end;
  END;

  -- Mail senza allegati
  PROCEDURE mail(
    p_from    VARCHAR2,
    p_to      VARCHAR2 := NULL,
    p_cc      VARCHAR2 := NULL,
    p_bcc     VARCHAR2 := NULL,
    p_subject VARCHAR2,
    p_message VARCHAR2,
    p_html    VARCHAR2 := 'N'
    ) IS
  BEGIN
--  mail_start(p_from, p_to, p_cc, p_bcc, p_subject, p_message);
    mail_start(p_from, p_to, p_cc, p_bcc, p_subject, p_message, p_html);
    mail_end;
  END;
  -- Sinonimo della mail precedente senza parametro p_html
  PROCEDURE mail_cc(
    p_from VARCHAR2,
    p_to VARCHAR2 := NULL,
    p_cc VARCHAR2 := NULL,
    p_bcc VARCHAR2 := NULL,
    p_subject VARCHAR2,
    p_message VARCHAR2
    ) IS
  BEGIN
    mail_start(p_from, p_to, p_cc, p_bcc, p_subject, p_message);
    mail_end;
  END;

  -- Mail con Allegato BLOB singolo
  PROCEDURE mail(
    p_from       VARCHAR2,
    p_to         VARCHAR2 := NULL,
    p_cc         VARCHAR2 := NULL,
    p_bcc        VARCHAR2 := NULL,
    p_subject    VARCHAR2,
    p_message    VARCHAR2,
    p_attachName VARCHAR2 ,
    p_attachBlob BLOB,
    p_html       VARCHAR2 := 'N'
    ) IS
  BEGIN
    mail_start(p_from, p_to, p_cc, p_bcc, p_subject, p_message);
    mail_attach(p_attachName,p_attachBlob);
    mail_end;
  END;
  -- Sinonimo della precednete mail senza parametro p_html
  PROCEDURE mail_blob(
    p_from       VARCHAR2,
    p_to         VARCHAR2 := NULL,
    p_cc         VARCHAR2 := NULL,
    p_bcc        VARCHAR2 := NULL,
    p_subject    VARCHAR2,
    p_message    VARCHAR2,
    p_attachName VARCHAR2 ,
    p_attachBlob BLOB
    ) IS
  BEGIN
    mail_start(p_from, p_to, p_cc, p_bcc, p_subject, p_message);
    mail_attach(p_attachName,p_attachBlob);
    mail_end;
  END;

  -- Mail con Allegato FileName e Directory (Oracle) 
  PROCEDURE mail(
    p_from       VARCHAR2,
    p_to         VARCHAR2 := NULL,
    p_cc         VARCHAR2 := NULL,
    p_bcc        VARCHAR2 := NULL,
    p_subject    VARCHAR2,
    p_message    VARCHAR2,
    p_attachFile VARCHAR2,
    p_Directory  VARCHAR2,  -- Nome Directory Oracle 
    p_html       VARCHAR2 := 'N'
    ) IS
  BEGIN
    mail_start(p_from, p_to, p_cc, p_bcc, p_subject, p_message);
    mail_attach(p_attachFile, p_Directory);
    mail_end;
  END; 
  -- Sinonimo della precedente senza parametro p_html
  PROCEDURE mail_file(
    p_from VARCHAR2,
    p_to VARCHAR2 := NULL,
    p_cc VARCHAR2 := NULL,
    p_bcc VARCHAR2 := NULL,
    p_subject VARCHAR2,
    p_message VARCHAR2,
    p_attachFile VARCHAR2,
    p_Directory  VARCHAR2  -- Nome Directory Oracle 
    ) IS
  BEGIN
    mail_start(p_from, p_to, p_cc, p_bcc, p_subject, p_message);
    mail_attach(p_attachFile, p_Directory);
    mail_end;
  END; 

  -- Determina la directory Oracle dal path del filesystem
  FUNCTION getDirectory(p_vDirectoryPath IN VARCHAR2) RETURN VARCHAR2 IS
    v_vDirectory VARCHAR2(30);
  BEGIN
    SELECT directory_name
      INTO v_vDirectory
      FROM all_directories d
     WHERE d.directory_path=p_vDirectoryPath
       AND rownum <2;

    RETURN v_vDirectory;
  EXCEPTION
    WHEN no_data_found THEN
      RETURN NULL;  
  END;

  -- Alias di Mail compatta 
  PROCEDURE Send_Mail(
    Sender     VARCHAR2,
    Recipients VARCHAR2,
    Subject    VARCHAR2,
    Message    VARCHAR2
    ) IS
  BEGIN
    mail(Sender, Recipients, Subject, Message);
  END;

END PKG_SENDMAIL;
/
