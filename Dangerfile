failure("Big PR") if git.lines_of_code > 1


all_touched_files  = git.added_files + git.modified_files + git.deleted_files
modified_db_files  = all_touched_files.select { |filepath| filepath.include? "db/" }
modified_app_files = all_touched_files.select { |filepath| filepath.include? "app/" }

if !modified_db_files.empty? && !modified_app_files.empty?
  msg = "Modified files in db/ and app/ inside the same PR!\n\n**db files**"
  modified_db_files.each { |file| msg += "\n- #{file}" }
  msg += "\n\n**app files**"
  modified_app_files.each { |file| msg += "\n- #{file}" }

  failure(msg)
end