module handler

fn test_extract_file_extension_from_mime_type() {
	extension := extract_file_extension_from_mime_type('image/png') or { '' }

	assert extension == 'png'
}
