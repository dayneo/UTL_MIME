CREATE OR REPLACE package utl_mime as

	MIME_VERSION constant varchar2(3) := '1.0';

	subtype MIME_DOCUMENT is clob;

	-- Creates a mime document as a clob.
	procedure create_mime(p_doc in out nocopy MIME_DOCUMENT);

	-- Parses the file to produce a mime document that can be manipulated
	procedure parse_mime(p_doc in out nocopy MIME_DOCUMENT, p_file in clob);

	-- Gets and sets a mime header
	procedure set_header(p_doc in out nocopy MIME_DOCUMENT, p_name in varchar2, p_value in varchar2);
	procedure get_header(p_doc in out nocopy MIME_DOCUMENT, p_name in varchar2, p_value out varchar2);

	-- Sets the content
	procedure set_content(p_doc in out nocopy MIME_DOCUMENT, p_content in clob, p_content_type in varchar2 default null);
	-- Binary file content will be base64 encoded automatically. 
	procedure set_content(p_doc in out nocopy MIME_DOCUMENT, p_content in blob, p_content_type in varchar2 default null);
	-- Returns the length of the content
	function get_length(p_doc in out nocopy MIME_DOCUMENT) return pls_integer;

	-- Returns true if the mime document is a multipart document
	function  is_multipart(p_doc in out nocopy MIME_DOCUMENT) return boolean;
	-- Returns the number of content parts in a multipart document.
	-- If it is not a multipart, but has content, then this function will return 1.
	function  parts_count(p_doc in out nocopy MIME_DOCUMENT) return pls_integer;
	-- Sets a header value on the given content part
	procedure set_header(p_doc in out nocopy MIME_DOCUMENT, p_part_index in pls_integer, p_name in varchar2, p_value in varchar2);
	-- Adds content in a multipart document
	-- If the document was not multipart to begin with, it will be now...
	procedure add_content(p_doc in out nocopy MIME_DOCUMENT, p_content in clob);
	function  add_content(p_doc in out nocopy MIME_DOCUMENT, p_content in clob) return pls_integer;
	procedure add_content(p_doc in out nocopy MIME_DOCUMENT, p_content in blob);
	function add_content(p_doc in out nocopy MIME_DOCUMENT, p_content in blob) return pls_integer;

	-- Gets the document as a clob
	function get_clob(p_doc in out nocopy MIME_DOCUMENT) return clob;

end utl_mime;
/

SHOW ERRORS
