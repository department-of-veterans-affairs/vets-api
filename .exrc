let g:ale_linters = {'ruby': ['rubocop']}
let g:ale_command_wrapper = 'docker-compose --log-level=ERROR run --rm --entrypoint="" vets-api'
let g:ale_filename_mappings = {
\ 'rubocop': [
\   ['/Users/buckley/projects/adhoc/code/vets-api', '/srv/vets-api/src'],
\ ],
\}
