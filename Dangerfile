# Warn if a pull request is too big
MAX_PR_SIZE = 250
EXCLUSIONS = ['Gemfile.lock', '.json', 'spec/fixtures/', '.txt', 'spec/support/vcr_cassettes/']

# takes form {"some/file.rb"=>{:insertions=>4, :deletions=>1}}
changed_files = git.diff.stats[:files]

filtered_changed_files = changed_files.reject { |key| EXCLUSIONS.any? { |exclusion| key.include?(exclusion) } }
lines_of_code = filtered_changed_files.sum { |_file, changes| (changes[:insertions] + changes[:deletions]) }

if lines_of_code > MAX_PR_SIZE
  warn("PR is exceeds `#{MAX_PR_SIZE}` LoC. Consider breaking up into multiple smaller ones.")
end

# Warn when a PR includes a simultaneous DB migration and application code changes
all_touched_files  = git.added_files + git.modified_files + git.deleted_files
db_files  = all_touched_files.select { |filepath| filepath.include? "db/" }
app_files = all_touched_files.select { |filepath| filepath.include? "app/" }

if !db_files.empty? && !app_files.empty?
  msg = "Modified files in `db/` and `app/` inside the same PR!\n\n**db file(s)**"
  db_files.each { |file| msg += "\n- #{file}" }
  msg += "\n\n**app file(s)**"
  app_files.each { |file| msg += "\n- #{file}" }
  msg += "\n\nIt is recommended to make db changes in their own PR since migrations do not run automatically with vets-api deployments. Application code must always be backwards compatible with the DB, both before and after migrations have been run."

  # resolves exception... encode': "\xE2" on US-ASCII (Encoding::InvalidByteSequenceError)
  msg.scrub!('_')

  warn(msg)
end