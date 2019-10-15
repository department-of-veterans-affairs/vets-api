MAX_PR_SIZE = 1
failure("PR is exceeds #{MAX_PR_SIZE} LoC. Consider breaking up into multiple smaller ones.") if git.lines_of_code > MAX_PR_SIZE


all_touched_files  = git.added_files + git.modified_files + git.deleted_files
db_files  = all_touched_files.select { |filepath| filepath.include? "db/" }
app_files = all_touched_files.select { |filepath| filepath.include? "app/" }

if !db_files.empty? && !app_files.empty?
  msg = "Modified files in db/ and app/ inside the same PR\n\n**db files**"
  db_files.each { |file| msg += "\n- #{file}" }
  msg += "\n\n**app files**"
  app_files.each { |file| msg += "\n- #{file}" }
  msg += "\n\nIt is recommended to make db changes in their own PR since migrations do not run automatically with vets-api deployments. Make sure application code is backwards compatible with the DB before and after migrations have been run."

  warn("Valid Encoding? = #{msg.valid_encoding?}")

  failure(msg.scrub('_'))
end

warn("Test warn")
failure("Test failure")