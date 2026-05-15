module model

import math
import time

pub struct File {
pub:
	id                 int    @[primary; sql: serial]
	repo_id            int    @[unique: 'file']
	name               string @[unique: 'file']
	parent_path        string @[unique: 'file']
	is_dir             bool
	branch             string @[unique: 'file']
	contributors_count int
	last_hash          string
	size               int
	is_size_calculated bool
	views_count        int
pub mut:
	last_msg  string
	last_time int
	commit    Commit @[skip]
}

pub fn (f File) url() string {
	file_type := if f.is_dir { 'tree' } else { 'blob' }

	if f.parent_path == '' {
		return '${file_type}/${f.branch}/${f.name}'
	}

	return '${file_type}/${f.branch}/${f.parent_path}/${f.name}'
}

pub fn (f &File) full_path() string {
	if f.parent_path == '' {
		return f.name
	}

	return f.parent_path + '/' + f.name
}

pub fn (f File) pretty_last_time() string {
	if f.last_time == 0 {
		return ''
	}
	return time.unix(f.last_time).relative()
}

fn pretty_size_bytes(size_in_bytes int) string {
	sizes := ['bytes', 'KB', 'MB', 'GB', 'TB']

	if size_in_bytes == 0 {
		return '0 bytes'
	}

	index := int(math.floor(math.log(size_in_bytes) / math.log(1024)))

	if index == 0 {
		return '${size_in_bytes} ${sizes[index]}'
	}

	size_in := math.round_sig(size_in_bytes / (math.pow(1024, index)), 2)

	return '${size_in} ${sizes[index]}'
}

pub fn (f File) pretty_size() string {
	if f.size == 0 {
		return 'n/a'
	}

	return pretty_size_bytes(f.size)
}

pub fn (f File) pretty_tree_size() string {
	if !f.is_dir || !f.is_size_calculated {
		return ''
	}

	return pretty_size_bytes(f.size)
}

struct FileInfo {
	name      string
	last_msg  string
	last_hash string
	last_time string
	size      string
}