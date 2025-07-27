

with interfaces.c;
use interfaces;

with text_io;

procedure Pipes is

  pragma Assertion_Policy(check);

  type Size_T is new Long_Integer;
  type Mode_T is new Integer;
  type File_Id is new Integer;
  subtype Ssize_T is Size_T;

  Global_tally : Ssize_T := 0;
  
  O_RDWR : aliased c.int := 0;
--  pragma import(C, O_RDWR, "O_RDWR");

  O_WRONLY : aliased c.int := 1;
 -- pragma import(C, O_WRONLY, "O_WRONLY");

  
  use type C.Int;
  
  procedure create_fifo(name : string) is
    Result : C.Int := -1;   
    subtype Path_Name_Type is String(name'first..name'last +1);
    My_Path : aliased Path_Name_Type := Name & Ascii.Nul;

    function Mkfifo(Path : access Path_Name_Type; Permission : Mode_t) return C.Int;
    pragma Import(C, mkfifo, "mkfifo");
   begin
     Result := Mkfifo(My_Path'access, 8#660# );
     pragma Assert(Result >= 0, "bad mkfifo:" & Result'Image);
   end create_fifo;
   -------------------------------
   
  function Open(name : string; Flags : Interfaces.C.Int) return File_id is
    subtype Path_Name_Type is String(name'first..name'last +1);
    My_Path : aliased Path_Name_Type := Name & Ascii.Nul;

    function cOpen(Path  : access Path_Name_Type;
                   Flags : Interfaces.C.Int;
                   Mode  : Mode_T ) return File_Id;
    pragma Import(C, cOpen, "open" );
    Result : file_id := -1;

  begin
    Result := cOpen(My_Path'access,Flags, 8#660#);
    pragma Assert(Result >= 0, "bad Open:" & Result'Image);
    return Result;
  end Open;
      
  -----------------------------------
        
  function Close( File : File_Id ) return C.Int;
  pragma import( C, Close ,"close" );
  
  
  ------------------------------------
  
  subtype message_type is string(1..4096);
  
  procedure Read(File : File_Id; Msg : in out Message_Type; len : out Ssize_T) is
  
    Message_Buffer : aliased message_type;
    function cRead(Fd    : File_Id;
                   Buf   : access message_type;
                   Count : Size_T ) return Ssize_T;
    pragma import( C, cRead , "read");
  begin
    Len := cRead(File, Message_Buffer'access, Size_T(message_type'last));
    pragma Assert(Len >= 0, "bad Read:" & Len'image);
    Msg := Message_Buffer;
  end Read;
    
  ------------------------------

  procedure Write(File : File_Id; Msg : in string) is
  
    subtype Value_Type is String(msg'first..msg'last +1);
    My_Value : aliased Value_Type := Msg & Ascii.Nul;

    function cWrite( Fd    : File_Id;
                     Buf   : access Value_Type;
                     Count : Size_T ) return Ssize_T;
    pragma import( C, cWrite , "write");
    dummy : Ssize_T;
  begin
    dummy := cWrite(File, My_Value'access, Size_T(My_Value'last));
    pragma Assert(dummy >= 0, "bad Write:" & dummy'image);
  end Write;
    
  -------------------------------

  procedure read_loop is
    fd : file_id;
    buf : message_type;
    len : Ssize_T;
    dummy : c.int  ;
  begin
    outer : loop
      text_io.put_line ("read_loop-outer: before open");
      fd := open("in_pipe", O_RDWR);
      inner : loop
        text_io.put_line ("read_loop-inner: before read");
        read(fd, buf, len);
        text_io.put_line ("read_loop-inner: read" & len'img & " bytes '" & buf(1..integer(len)) & "'");
        exit inner when len = 0;
        Global_tally := Global_tally + len;
      end loop inner;
      text_io.put_line ("read_loop-outer:  before close");      
      dummy := close(fd);
    end loop outer;
  end read_loop;
  ------------------------------
  
  task writer is
    entry start;
  end writer;

  task body writer is
    fd : file_id;
    dummy : c.int;
  begin
    text_io.put_line ("task writer: wait for start");      

    accept start; -- wait here until called. Rendez-vouz is done here
    text_io.put_line ("task writer: start called");      
    
    loop
      text_io.put_line ("task writer-loop: wait for open call by others");      
      fd := open("out_pipe", O_WRONLY);  -- block open, until a reader comes along
      text_io.put_line ("task writer: wrote" & Global_tally'image);      
      Write(fd,Global_tally'image);
      dummy := Close(fd);
      delay 0.0; -- force context change
    end loop;

  end writer;
  ---------------------------------
  
begin
    -- haphazardly create the fifos.  It's ok if the fifos already exist,
    --   but things won't work out if the files exist but are not fifos;
    --   if we don't have write permission; if we are on NFS; etc.  Just
    --   pretend it works.

  create_fifo("in_pipe");
  create_fifo("out_pipe");

  writer.start;
  read_loop;
    
end Pipes;





