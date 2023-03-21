# frozen_string_literal: true

namespace :va_forms do
  QUERY = File.read(Rails.root.join('modules', 'va_forms', 'config', 'graphql_query.txt'))
  SOCKS_URL = Settings.docker_debugging&.socks_url ? Settings.docker_debugging.socks_url : 'socks://localhost:2001'
  FORMS_URL = Settings.va_forms.drupal_url
  CURL_COMMAND = <<~CURL_COMMAND.freeze
    curl -i -X POST -k -u  #{Settings.va_forms.drupal_username}:#{Settings.va_forms.drupal_password} --proxy "#{SOCKS_URL}" -d '#{{ query: QUERY }.to_json}' #{FORMS_URL}/graphql
  CURL_COMMAND

  # rubocop:disable Metrics/MethodLength
  # for some strange reason within docker faraday fails over socks.
  def fetch_all_forms
    results, error, exit_code = nil
    puts "starting fetch from #{FORMS_URL}..."
    Open3.popen3(CURL_COMMAND) do |_stdin, stdout, stderr, wait_thr|
      results = stdout.read
      error = stderr.read
      exit_code = wait_thr.value
    end
    results =~ /(\{"data.*)/m
    data = Regexp.last_match(1)
    unless exit_code.success?
      puts "Failed to fetch data from #{FORMS_URL}\n #{error}"
      return
    end
    puts 'Parsing data.'
    forms_data = JSON.parse(data)
    puts 'Populating database, this takes time.'
    num_rows = 0
    forms_data.dig('data', 'nodeQuery', 'entities').each do |form|
      VAForms::FormReloader.new.build_and_save_form(form)
      num_rows += 1
      puts "#{num_rows} completed" if (num_rows % 10).zero?
    rescue => e
      puts "#{form['fieldVaFormNumber']} failed to import into forms database"
      puts e.message
      next
    end
    puts "#{num_rows} added/updated in the database!"
  end
  # rubocop:enable Metrics/MethodLength

  task fetch_latest: :environment do
    VAForms::FormReloader.new.perform
  end

  task fetch_latest_curl: :environment do
    fetch_all_forms
  end
end
