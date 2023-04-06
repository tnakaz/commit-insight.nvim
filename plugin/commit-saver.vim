if exists('g:loaded_commitsaver')
  finish
endif
let g:loaded_commitsaver = 1

command! -nargs=1 CommitSaver lua require('commit-saver').show_commit_info(<f-args>)
