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

  desc 'Build mock MVI yaml database for users in given CSV'
  task :mock_database, [:csvfile] => [:environment] do |_, args|
    raise 'No input CSV provided' unless args[:csvfile]
    csv = CSV.open(args[:csvfile], headers: true)
    csv.each_with_index do |row, i|
      begin
        bd = DateTime.iso8601(row['birth_date']).strftime('%Y-%m-%d')
        user = User.new(
          first_name: row['first_name'],
          last_name: row['last_name'],
          middle_name: row['middle_name'],
          birth_date: bd,
          gender: row['gender'],
          ssn: row['ssn'],
          email: row['email'],
          uuid: SecureRandom.uuid,
          loa: { current: LOA::THREE, highest: LOA::THREE }
        )
        if user.va_profile.nil?
          puts "Row #{i} #{row['first_name']} #{row['last_name']}: No MVI profile"
          next
        end
      rescue => e
        puts "Row #{i} #{row['first_name']} #{row['last_name']}: #{e.message}"
      end
    end
  end

  # attribute :icn, String
  # attribute :mhv_ids, Array[String]
  # attribute :vha_facility_ids, Array[String]
  # attribute :edipi, String
  # attribute :participant_id, String

  # 796002073

  desc "Given a ssn update a mocked user's correlation ids"
  task :update_ids, [:ssn, :mhv_ids, :vha_facility_ids, :edipi, :participant_id] => [:environment] do |_, args|
    ssn = args[:ssn]
    path = File.join(Betamocks.configuration.cache_dir, 'mvi', 'profile', "#{ssn}.yml")
    xml = YAML.load(File.read(path)).dig(:body)
    doc = Nokogiri::XML(xml)
    puts doc
    puts "*** --- ***"
    puts doc.at('patient').inspect
  end
end

def locate_element(el, path)
  return nil unless el
  el.locate(path)&.first
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
