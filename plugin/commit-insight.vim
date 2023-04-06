if exists('g:loaded_commitinsight')
  finish
endif
let g:loaded_commitinsight = 1

command! -nargs=1 CommitInsight lua require('commit-insight').show_commit_info(<f-args>)
