# frozen_string_literal: true

module ModuleHelper
  def module_generator_file_insert(file_path, options = {})
    insert_file = File.read(file_path)

    matcher_regex = options[:regex] || /path 'modules' do(.*)end/m
    existing_entries = insert_file.match(matcher_regex).to_s.split("\n")

    ## removes the begining and ending matcher
    existing_entries.pop
    existing_entries.shift

    new_entry = options[:new_entry]

    existing_entries.each do |entry|
      # if the current entry is alphabetically greater
      # insert new entry before
      if options[:insert_matcher] < entry.strip
        insert_into_file file_path, new_entry.to_s, before: entry.to_s
        return true
      end
    end
  end
end
