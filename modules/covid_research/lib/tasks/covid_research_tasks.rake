# frozen_string_literal: true

# desc "Explaining what the task does"
# task :covid_research do
#   # Task goes here
# end

desc 'Rebuild encrypted-form.json when valid-intake-submission.json changes'
task rebuild_encrypted_fixture: :environment do
  fixture_dir = CovidResearch::Engine.root.join('spec', 'fixtures', 'files')
  submission = JSON.parse(File.read(File.join(fixture_dir, 'valid-intake-submission.json')))
  formatter = CovidResearch::RedisFormat.new
  formatter.form_data = JSON.generate(submission)

  File.open(File.join(fixture_dir, 'encrypted-form.json'), 'w') do |f|
    f.puts formatter.to_json
  end
end

desc 'Rebuild encrypted-update-form.json when valid-update-submission.json changes'
task rebuild_encrypted_update_fixture: :environment do
  fixture_dir = CovidResearch::Engine.root.join('spec', 'fixtures', 'files')
  submission = JSON.parse(File.read(File.join(fixture_dir, 'valid-update-submission.json')))
  formatter = CovidResearch::RedisFormat.new
  formatter.form_data = JSON.generate(submission)

  File.open(File.join(fixture_dir, 'encrypted-update-form.json'), 'w') do |f|
    f.puts formatter.to_json
  end
end
