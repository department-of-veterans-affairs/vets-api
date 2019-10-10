failure("Big PR") if git.lines_of_code > 1


all_touched_files  = git.added_files + git.modified_files + git.deleted_files
modified_db_files  = all_touched_files.select { |filepath| filepath.include? "db/" }
modified_app_files = all_touched_files.select { |filepath| filepath.include? "app/" }
failure("Modified files in db/ and app/ inside the same PR!\ndb files:#{modified_db_files.to_a}\napp files:#{modified_app_files.to_a}") if !modified_db_files.empty? && !modified_app_files.empty?