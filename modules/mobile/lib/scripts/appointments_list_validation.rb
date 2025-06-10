# frozen_string_literal: true

require 'faraday'
require 'json'
require 'pry'

# This script was written to help us validate what appears in the web appointments indexes
# vs the mobile appointments index. It compares the appointment ids in the web html against
# the appointments received from the mobile appointments index. It then formats the results
# to highlight which ids aren't present in both sources.

# This script is only being used for validating v2 appointments work and will probably not be of
# any value for long. Delete it once we're confident that v2 appointments are working correctly.

# INSTRUCTIONS FOR USE:
# 1) in the web app, use the inspector to copy the html. Do not attempt to save the html by saving
# the web page. That approach omitted the important parts. Paste the html into files with a
# .txt extension in a directory that contains no other txt files.
# 2) fetch an access token for the test user
# 3) in terminal, run:
# bundle exec ruby modules/mobile/lib/scripts/appointments_list_validation.rb path/to/dir/with/txt/files access_token

# WARNING: for some reason the useCache param does not work. You may have to break the cache via postman instead.

class AppointmentsListValidation
  def initialize(path_to_html, access_token)
    @path_to_html = path_to_html
    @access_token = access_token
  end

  def compare_sources
    results = {
      match: in_both,
      web_only: in_web_only,
      mobile_only: in_mobile_only
    }
    Rails.logger.debug results
  end

  private

  def in_both
    web_ids & mobile_ids
  end

  def in_web_only
    web_ids.reject { |web_id| mobile_ids.include?(web_id) }
  end

  def in_mobile_only
    mobile_ids.reject { |mobile_id| web_ids.include?(mobile_id) }
  end

  # doing this with nokogiri would be preferred, but this was easier to get working
  def web_ids
    @web_ids ||= begin
      texts = read_text_files
      texts.map { |text| text.scan(/data-request-id="(\d+)"/) }.flatten
    end
  end

  def mobile_ids
    @mobile_ids ||= begin
      response = get_mobile_appointments
      parsed = JSON.parse(response.body)
      parsed['data'].pluck('id')
    end
  end

  def read_text_files
    files = Dir["#{@path_to_html}/*.txt"]
    files.map do |file|
      Rails.logger.debug { "READING FILE: #{file}" }
      File.read(file)
    end
  end

  def get_mobile_appointments
    path = 'mobile/v0/appointments'
    params = {
      'page[size]' => 1000,
      'include[]' => 'pending'
    }
    connection.get(path, params)
  end

  def connection
    Faraday.new(
      url: 'https://staging-api.va.gov',
      headers: {
        'Content-Type' => 'application/json',
        'Authorization' => "Bearer #{@access_token}",
        'X-Key-Inflection' => 'camel'
      }
    )
  end
end

if __FILE__ == $PROGRAM_NAME
  path_to_html = ARGV[0]
  access_token = ARGV[1]
  script = AppointmentsListValidation.new(path_to_html, access_token)
  script.compare_sources
end
