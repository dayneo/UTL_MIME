CREATE OR REPLACE package body utl_mime as

	CRLF constant varchar2(2) := chr(13) || chr(10);

	procedure write_append(p_doc in out nocopy clob, p_content in varchar2) is
	begin

		dbms_lob.writeAppend(p_doc, length(p_content), p_content);

	end write_append;

	procedure write_line(p_doc in out nocopy clob, p_content in varchar2 default '') is
	begin

		write_append(p_doc, p_content || CRLF);

	end write_line;

	procedure write_append(p_doc in out nocopy clob, p_content in clob) is

		l_sz     constant pls_integer := 32767;
		l_length pls_integer;
		l_amount pls_integer;
		l_offset pls_integer;
		l_buf    varchar2(32767);

		-- longops variables
		SECONDS_IN_DAY constant pls_integer := 24*60*60;
		l_start   date;
		l_rindex  binary_integer;
		l_slno    binary_integer;
		l_target  binary_integer;

	begin

		-- TODO: Provide longops for clobs over 32767*32=+/-1MB
		l_rindex := dbms_application_info.set_session_longops_nohint;
		l_start   := sysdate;

		l_offset  := 1;
		l_amount  := l_sz;
		l_length  := dbms_lob.getLength(p_content);
		while l_offset < l_length loop

			l_amount := least(l_sz, (l_length - l_offset)+1);
			l_buf    := dbms_lob.substr(p_content, l_amount, l_offset);
			dbms_lob.writeAppend(p_doc, l_amount, l_buf);
			l_offset := l_offset + l_amount;

			if (sysdate - l_start)*SECONDS_IN_DAY > 1 then

				dbms_application_info.set_session_longops(l_rindex, l_slno,
				                                          'UTL_MIME.WRITE_APPEND', l_target, 0,
																		l_offset, l_length,
																		'Chars sent', 'Chars');

			end if;

		end loop;

	end write_append;

	procedure write_append(p_doc in out nocopy clob, p_content in blob) is

		l_BASE64_LN_LENGTH constant pls_integer := 57;
		l_result           clob := empty_clob();
		l_pos              number := 1;
		l_amount           number;
		l_buffer           raw(32767);
		l_string           varchar2(32767);
		l_length           pls_integer;

		-- longops variables
		SECONDS_IN_DAY constant pls_integer := 24*60*60;
		l_start   date;
		l_rindex  binary_integer;
		l_slno    binary_integer;
		l_target  binary_integer;

	begin

		-- TODO: Provide longops for clobs over 32767*32=+/-1MB
		l_rindex := dbms_application_info.set_session_longops_nohint;
		l_start   := sysdate;

		dbms_lob.createTemporary(l_result, true, dbms_lob.CALL);
		l_length  := dbms_lob.getLength(p_content);
		while l_pos < l_length loop

			l_amount := l_BASE64_LN_LENGTH;
			dbms_lob.read(p_content, l_amount, l_pos, l_buffer);
			l_buffer := utl_encode.base64_encode(l_buffer);
			l_string := utl_raw.cast_to_varchar2(l_buffer);
			write_line(p_doc, l_string);
			l_pos    := l_pos + l_BASE64_LN_LENGTH;

			if (sysdate - l_start)*SECONDS_IN_DAY > 2 then

				dbms_application_info.set_session_longops(l_rindex, l_slno,
				                                          'UTL_MIME.WRITE_APPEND', l_target, 0,
																		least(l_pos, l_length), l_length,
																		'Bytes sent', 'Bytes');

			end if;

		end loop;

	end write_append;

	-- Credit: Tom Kyte
	--         http://asktom.oracle.com/pls/asktom/f?p=100:11:::::P11_QUESTION_ID:1533006062995
	-- Provides an efficient string replace mechanism
	-- This version of the replace performs a search for p_what and replaces the first instance it 
	-- finds with p_with.
	-- DPO NOTE: I found that I received data corruption for files over a few kb. The issue is
	--           due to copying from lob A to lob A. To resolve the issue, rather copy to a temp
	--           lob and then copy from the temp lob back to lob A.
	procedure lob_replace(p_lob in out nocopy clob, p_what in varchar2, p_with in varchar2) is

		l_n    number;

	begin

		-- Only do the replace if the search phrase was actually found.
		l_n := dbms_lob.instr(p_lob, p_what);
		if (nvl(l_n, 0) > 0) then
			
			-- Copy the characters from the position where the phrase ends
			-- to the position where the replacement text would end.
			-- Then simply overwrite the affected area with the replacement text.
			dbms_lob.copy(p_lob, p_lob, dbms_lob.getlength(p_lob), l_n + length(p_with), l_n + length(p_what));
			dbms_lob.write(p_lob, length(p_with), l_n, p_with);

			-- If the search phrase was longer than the replacement text, then the clob
			-- is actually shorter than it used to be. So trim the extra characters off 
			-- of the end.
			if (length(p_what) > length(p_with)) then

				dbms_lob.trim(p_lob, dbms_lob.getlength(p_lob)-(length(p_what)-length(p_with)));

			end if;

		end if;

	end lob_replace;

	-- This version of replace makes use of a start and amount to determine what gets replaced.
	procedure lob_replace(p_lob in out nocopy clob, p_offset in pls_integer, p_amount in pls_integer, p_with in varchar2) is

		l_tmp clob;

	begin

		if p_offset = dbms_lob.getLength(p_lob)+1 then

			-- special case where we are appending to the file.
			dbms_lob.writeAppend(p_lob, length(p_with), p_with);

		else

			-- NOTE: I was forced to use a temporary lob for copying of the characters.
			--       I found that copying from lob A to lob A caused data corruption
			--       around line 208... 
			dbms_lob.createTemporary(l_tmp, true);
			begin

				dbms_lob.copy(l_tmp, p_lob, dbms_lob.LOBMAXSIZE, 
								  1, p_offset + p_amount);

				-- Copy the characters from the position where the phrase ends
				-- to the position where the replacement text would end.
				-- Then simply overwrite the affected area with the replacement text.
				dbms_lob.copy(p_lob, l_tmp, dbms_lob.LOBMAXSIZE, 
								  p_offset + length(p_with), 1);

				dbms_lob.freeTemporary(l_tmp);

			exception
				when OTHERS then
					dbms_lob.freeTemporary(l_tmp);
					raise;
			end;

			dbms_lob.write(p_lob, length(p_with), p_offset, p_with);

			-- If the replaced area was longer than the replacement text, then the clob
			-- is actually shorter than it used to be. So trim the extra characters off 
			-- of the end.
			if (p_amount > length(p_with)) then

				dbms_lob.trim(p_lob, dbms_lob.getlength(p_lob)-(p_amount-length(p_with)));

			end if;

		end if;

	end lob_replace;

	function get_header_length(p_doc in out nocopy clob) return pls_integer is

		l_pos pls_integer;

	begin

		l_pos := 1;
		l_pos := dbms_lob.instr(p_doc, CRLF || CRLF, l_pos);
		if l_pos = 0 then

			raise_application_error(-20000, 'Malformed document. Header terminator not found.');

		else

			-- pos 1 is doc length 0
			-- but, since every header includes CRLF we must add 2 back to include the 
			-- final header CRLF. The result is (l_pos-1)+2=l_pos+1
			return l_pos+1; 

		end if;

	end get_header_length;

	function get_multipart_boundary(p_doc in out nocopy MIME_DOCUMENT) return varchar2 is

		l_value varchar2(32767);

	begin

		get_header(p_doc, 'Content-Type', l_value);
		if l_value like 'multipart/%' then

			l_value := regexp_substr(l_value, 'boundary=.*$');
			l_value := ltrim(l_value, 'boundary=');
			return l_value;

		else

			return null;

		end if;

	end get_multipart_boundary;

	function get_part_offset(p_doc in out nocopy MIME_DOCUMENT, p_part in pls_integer) return pls_integer is

		l_pos      pls_integer;
		l_cnt      pls_integer;
		l_boundary varchar2(78); -- RFC line size limitation

	begin

		l_cnt := 0;
		l_pos := get_header_length(p_doc) + length(CRLF);
		l_boundary := '--' || get_multipart_boundary(p_doc) || CRLF;

		loop

			l_pos := dbms_lob.instr(p_doc, l_boundary, l_pos);
			exit when l_pos = 0 or l_pos is null;

			if l_cnt = p_part then
				return l_pos;
			end if;

			l_cnt := l_cnt + 1;
			l_pos := l_pos + length(l_boundary);

		end loop;

		raise_application_error(-20000, 'Invalid part number [' || p_part || ']');

	end get_part_offset;

	function get_header_length(p_doc in out nocopy clob, p_part in pls_integer) return pls_integer is

		l_offset   pls_integer;
		l_pos      pls_integer;
		l_boundary varchar2(78);

	begin

		l_boundary := '--' || get_multipart_boundary(p_doc) || CRLF;
		l_offset   := get_part_offset(p_doc, p_part) + length(l_boundary);

		l_pos := dbms_lob.instr(p_doc, CRLF || CRLF, l_offset - length(CRLF)); -- -CRLF to cater for empty headers
		if l_pos = 0 then

			raise_application_error(-20000, 'Malformed document. Header terminator not found.');

		else

			-- l_pos - l_offset = length
			-- but, since every header line includes CRLF we must add 2 back to include the 
			-- final header line CRLF. The result is (l_pos - l_offset)+2
			if l_pos < l_offset then
				return 0;
			else
				return (l_pos - l_offset) + 2; 
			end if;

		end if;

	end get_header_length;


	-- Creates a mime document as a clob.
	procedure create_mime(p_doc in out nocopy MIME_DOCUMENT) is

		l_ver_hdr varchar2(32767);

	begin

		if p_doc is null then

			dbms_lob.createTemporary(p_doc, true);

		end if;

		write_line(p_doc, 'MIME-Version: ' || MIME_VERSION);
		write_line(p_doc, '');

	end create_mime;

	procedure parse_mime(p_doc in out nocopy MIME_DOCUMENT, p_file in clob) is
	begin

		p_doc := p_file;

	end parse_mime;

	function get_length(p_doc in out nocopy MIME_DOCUMENT) return pls_integer is

		l_offset pls_integer;
		l_length pls_integer;

	begin

		l_offset := get_header_length(p_doc) + 1 + length(CRLF);
		l_length := dbms_lob.getLength(p_doc) - length(CRLF);
		if l_length <= l_offset then
			return 0;
		else
			return l_length - (l_offset - 1);
		end if;

	end get_length;


	function is_multipart(p_doc in out nocopy MIME_DOCUMENT) return boolean is

		l_value varchar2(32767);

	begin

		get_header(p_doc, 'Content-Type', l_value);

		if l_value like 'multipart/%' then

			return true;

		else

			return false;

		end if;

	end is_multipart;

	function parts_count(p_doc in out nocopy MIME_DOCUMENT) return pls_integer is

		l_boundary varchar2(32767);
		l_pos      pls_integer;
		l_value    pls_integer;

	begin

		l_boundary := get_multipart_boundary(p_doc);

		if l_boundary is null then

			-- TODO: determine if there is content, ie. content-length > 0. If so, then return 1.
			raise_application_error(-20000, 'Not implemented');

		else

			l_boundary:= '--' || l_boundary || CRLF;
			loop
				l_pos  := dbms_lob.instr(p_doc, l_boundary, l_pos);
				exit when l_pos = 0 or l_pos is null;

				l_value:= l_value + 1;
				l_pos  := l_pos + length(l_boundary);

			end loop;
			
			return l_value;

		end if;

	end parts_count;


	-- Will add or overwrite an existing header
	procedure set_header(p_doc in out nocopy MIME_DOCUMENT, p_name in varchar2, p_value in varchar2) is

		l_new_hdr varchar2(32767);

		l_pattern varchar2(32767);
		l_pos     pls_integer;
		l_eol_pos pls_integer;
		l_amt     pls_integer;

	begin

		if p_value like 'multipart/%' then

			-- TODO: Take special action to make sure the document conforms
			null;

		end if;

		l_new_hdr := p_name || ': ' || p_value || CRLF;

		l_pattern := p_name || ': ';
		l_pos := dbms_lob.instr(p_doc, l_pattern);
		if l_pos = 0 
		or l_pos > get_header_length(p_doc) then

			-- If the header does not exist, then append to the end
			-- of the header block.
			l_pos := get_header_length(p_doc) + 1; 
			lob_replace(p_doc, l_pos, 0, l_new_hdr);

		else

			-- The header exists. Overwrite the existing value.
			l_eol_pos := dbms_lob.instr(p_doc, CRLF, l_pos); 
			l_amt     := (l_eol_pos - l_pos) + 1; -- +1 to include the CRLF
			lob_replace(p_doc, l_pos, l_amt, l_new_hdr);

		end if;

	end set_header;

	procedure get_header(p_doc in out nocopy MIME_DOCUMENT, p_name in varchar2, p_value out varchar2) is

		l_pattern varchar2(32767);
		l_pos     pls_integer;
		l_eol_pos pls_integer;
		l_amt     pls_integer;

	begin

		l_pattern := p_name || ': ';
		l_pos := dbms_lob.instr(p_doc, l_pattern, 1);
		if l_pos = 0 
		or l_pos > get_header_length(p_doc) then

			-- header not found
			-- ? Throw NO_DATA_FOUND ?
			p_value := null;

		else

			l_pos     := l_pos + length(l_pattern);
			l_eol_pos := dbms_lob.instr(p_doc, CRLF, l_pos);
			l_amt     := l_eol_pos - l_pos;
			p_value   := dbms_lob.substr(p_doc, l_amt, l_pos);

		end if;

	end get_header;

	procedure set_header(p_doc in out nocopy MIME_DOCUMENT, p_part_index in pls_integer, p_name in varchar2, p_value in varchar2) is

		l_new_hdr  varchar2(32767);

		l_offset   pls_integer;
		l_boundary varchar2(78);

		l_pattern  varchar2(32767);
		l_pos      pls_integer;
		l_eol_pos  pls_integer;
		l_amt      pls_integer;

	begin

		l_new_hdr := p_name || ': ' || p_value || CRLF;

		l_boundary:= '--' || get_multipart_boundary(p_doc) || CRLF;
		l_offset  := get_part_offset(p_doc, p_part_index) + length(l_boundary);

		l_pattern := p_name || ': ';
		l_pos := dbms_lob.instr(p_doc, l_pattern, l_offset);
		if l_pos = 0 
		or l_pos > (l_offset + get_header_length(p_doc, p_part_index)) then

			-- If the header does not exist, then append to the end
			-- of the header block.
			l_pos := l_offset + get_header_length(p_doc, p_part_index); 
			lob_replace(p_doc, l_pos, 0, l_new_hdr);

		else

			-- The header exists. Overwrite the existing value.
			l_eol_pos := dbms_lob.instr(p_doc, CRLF, l_pos); 
			l_amt     := (l_eol_pos - l_pos) + 1; -- +1 to convert into a length
			lob_replace(p_doc, l_pos, l_amt, l_new_hdr);

		end if;

	end set_header;

	procedure add_content(p_doc in out nocopy MIME_DOCUMENT, p_content in clob) is

		l_dummy pls_integer;

	begin

		l_dummy := add_content(p_doc, p_content);

	end add_content;

	function add_content(p_doc in out nocopy MIME_DOCUMENT, p_content in clob) return pls_integer is

		l_parts       pls_integer;
		l_boundary    varchar2(78); -- limited by RFC 5322
		l_eof_offset  pls_integer;

	begin

		l_parts := parts_count(p_doc);

		if l_parts = 0
		and not is_multipart(p_doc) then

			set_content(p_doc, p_content);
			return 0;

		else

			l_boundary := '--' || get_multipart_boundary(p_doc);

			-- find the trailing boundary
			if get_length(p_doc) != 0 then

				l_eof_offset := dbms_lob.instr(p_doc, l_boundary || '--' || CRLF);
				if l_eof_offset = 0 then

					raise_application_error(-20000, 'Malformed document. Boundary termination not found.');

				end if;

				-- remove the trailing boundary
				dbms_lob.trim(p_doc, l_eof_offset-1);

			end if;

			write_line(p_doc, l_boundary);
			write_line(p_doc, ''); -- blank headers
			write_append(p_doc, p_content);
			write_line(p_doc, ''); -- trailing CRLF representing end of content
			write_line(p_doc, l_boundary || '--'); -- closing boundary and final CRLF

			return l_parts + 1;

		end if;

	end add_content;

	procedure add_content(p_doc in out nocopy MIME_DOCUMENT, p_content in blob) is

		l_dummy pls_integer;

	begin

		l_dummy := add_content(p_doc, p_content);

	end add_content;

	function add_content(p_doc in out nocopy MIME_DOCUMENT, p_content in blob) return pls_integer is

		l_parts       pls_integer;
		l_boundary    varchar2(78); -- limited by RFC 5322
		l_eof_offset  pls_integer;

	begin

		l_parts := parts_count(p_doc);

		if l_parts = 0
		and not is_multipart(p_doc) then

			set_content(p_doc, p_content);
			return 0;

		else

			l_boundary := '--' || get_multipart_boundary(p_doc);

			-- find the trailing boundary
			if get_length(p_doc) != 0 then

				l_eof_offset := dbms_lob.instr(p_doc, l_boundary || '--' || CRLF);
				if l_eof_offset = 0 then

					raise_application_error(-20000, 'Malformed document. Boundary termination not found.');

				end if;

				-- remove the trailing boundary
				dbms_lob.trim(p_doc, l_eof_offset-1);

			end if;

			write_line(p_doc, l_boundary);
			write_line(p_doc, 'Content-Transfer-Encoding: base64'); -- will be base64 encoded
			write_line(p_doc, ''); -- end of headers
			write_append(p_doc, p_content);
			write_line(p_doc, ''); -- trailing CRLF representing end of content
			write_line(p_doc, l_boundary || '--'); -- closing boundary and final CRLF

			return l_parts + 1;

		end if;

	end add_content;

	procedure set_content(p_doc in out nocopy MIME_DOCUMENT, p_content in clob, p_content_type in varchar2 default null) is
	begin

		if p_content_type is not null then

			set_header(p_doc, 'Content-Type', p_content_type);

		end if;

		write_append(p_doc, p_content);

	end set_content;

	procedure set_content(p_doc in out nocopy MIME_DOCUMENT, p_content in blob, p_content_type in varchar2 default null) is
	begin

		if p_content_type is not null then

			set_header(p_doc, 'Content-Type', p_content_type);

		end if;

		set_header(p_doc, 'Content-Transfer-Encoding', 'base64');

		write_append(p_doc, p_content);

	end set_content;

	function get_clob(p_doc in out nocopy MIME_DOCUMENT) return clob is
	begin

		return p_doc;

	end get_clob;

end utl_mime;
/

SHOW ERRORS
