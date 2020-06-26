# frozen_string_literal: true

desc 'imports conditions into disability_contentions table'
task :import_conditions, [:csv_path] => [:environment] do |_, args|
  raise 'No CSV path provided' unless args[:csv_path]

  CSV.foreach(args[:csv_path], headers: true) do |row|
    condition = DisabilityContention.find_or_create_by(code: row['code'])
    condition.update!(medical_term: row['medical_term'], lay_term: row['lay_term'])
  end
end
