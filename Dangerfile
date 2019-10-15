# PR too big
MAX_PR_SIZE = 250
failure("PR is exceeds #{MAX_PR_SIZE} LoC. Consider breaking up into multiple smaller ones.") if git.lines_of_code > MAX_PR_SIZE


# simultaneous migration & app code warning
all_touched_files  = git.added_files + git.modified_files + git.deleted_files
db_files  = all_touched_files.select { |filepath| filepath.include? "db/" }
app_files = all_touched_files.select { |filepath| filepath.include? "app/" }

if !db_files.empty? && !app_files.empty?
  msg = "Modified files in db/ and app/ inside the same PR!\n\n**db file(s)**"
  db_files.each { |file| msg += "\n- #{file}" }
  msg += "\n\n**app file(s)**"
  app_files.each { |file| msg += "\n- #{file}" }
  msg += "\n\nIt is recommended to make db changes in their own PR since migrations do not run automatically with vets-api deployments. Application code must always be backwards compatible with the DB, both before and after migrations have been run."

  # resolves exception... encode': "\xE2" on US-ASCII (Encoding::InvalidByteSequenceError)
  msg.scrub!('_')

  failure(msg)
end