# frozen_string_literal: true
require 'csv'

namespace :mvi do
  desc 'Given user attributes, run a find candidate query'
  task find: :environment do
    unless valid_user_vars
      raise ArgumentError, 'Run the task with all required attributes: bundle exec rake mvi:find first_name="John"
middle_name="W" last_name="Smith" birth_date="1945-01-25" gender="M" ssn="555443333"'
    end

    begin
      user = User.new(
        first_name: ENV['first_name'],
        last_name: ENV['last_name'],
        middle_name: ENV['middle_name'],
        birth_date: ENV['birth_date'],
        gender: ENV['gender'],
        ssn: ENV['ssn'],
        email: 'foo@bar.com',
        uuid: SecureRandom.uuid,
        loa: {
          current: LOA::THREE,
          highest: LOA::THREE
        }
      )
      puts Oj.dump(
        edipi: user.edipi,
        icn: user.icn,
        mhv_correlation_id: user.mhv_correlation_id,
        participant_id: user.participant_id,
        va_profile: user.va_profile
      )
    rescue => e
      puts "User query failed: #{e.message}"
    end
  end
end

def valid_user_vars
  date_valid = validate_date(ENV['birth_date'])
  name_valid = ENV['first_name'] && ENV['middle_name'] && ENV['last_name']
  attrs_valid = ENV['gender'] && ENV['ssn']
  date_valid && name_valid && attrs_valid
end

def validate_date(s)
  raise ArgumentError, 'Date string must be of format YYYY-MM-DD' unless s =~ /\d{4}-\d{2}-\d{2}/
  Time.parse(s).utc
  true
rescue => e
  puts e.message
  false
end
