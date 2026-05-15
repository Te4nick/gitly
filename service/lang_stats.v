module service

import model {LangStat}

const min_lang_summary_pct = 5 // pct is stored in tenths of a percent, so 5 is 0.5%.

const test_lang_stats = [
	LangStat{
		name:        'V'
		pct:         989
		lines_count: 96657
		color:       '#5d87bd'
	},
	LangStat{
		name:        'JavaScript'
		lines_count: 1131
		color:       '#f1e05a'
		pct:         11
	},
]

fn (s RepoService) add_lang_stat(lang_stat LangStat) ! {
	sql s.db {
		insert lang_stat into LangStat
	}!
}

pub fn (s RepoService) find_repo_lang_stats(repo_id int) []LangStat {
	stats := sql s.db {
		select from LangStat where repo_id == repo_id order by pct desc
	} or { return []LangStat{} }
	return stats.filter(it.pct >= min_lang_summary_pct)
}

fn (s RepoService) remove_repo_lang_stats(repo_id int) ! {
	sql s.db {
		delete from LangStat where repo_id == repo_id
	}!
}
