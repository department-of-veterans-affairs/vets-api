# frozen_string_literal: true
require 'csv'
require 'mvi/responses/id_parser'

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

  desc "Given a ssn update a mocked user's correlation ids"
  task :update_ids, [:environment] do
    ssn = ENV['ssn']
    icn = ENV['icn']
    edipi = ENV['edipi']
    participant_id = ENV['participant_id']
    mhv_ids = ENV['mhv_ids']&.split(' ')
    vha_facility_ids = ENV['vha_facility_ids']&.split(' ')

    update_ids(ssn, icn, edipi, participant_id, mhv_ids, vha_facility_ids)
  end

  desc 'Create missing cache files from mock_mvi_responses.yml'
  task :migrate_cache_files, [:environment] do
    yaml = YAML.load(
      File.read(File.join('config', 'mvi_schema', 'mock_mvi_responses.yml'))
    )
    template = Liquid::Template.parse(
      File.read(File.join('config', 'mvi_schema', 'mvi_template.xml'))
    )
    yaml['find_candidate'].each do |k, v|
      cache_file = File.join('config', 'betamocks', 'cache', 'mvi', 'profile', "#{k}.yml")
      unless File.exist? cache_file
        puts "user with ssn #{k} not found, generating cache file"
        profile = MVI::Models::MviProfile.new(v)
        create_cache_from_profile(cache_file, profile, template)
      end
    end
  end

  desc 'Update cache file ids from mock_mvi_responses.yml'
  task :batch_update_ids, [:environment] do
    yaml = YAML.load(
      File.read(File.join('config', 'mvi_schema', 'mock_mvi_responses.yml'))
    )

    yaml['find_candidate'].each do |k, v|
      update_ids
    end
  end
end

def update_ids(ssn, icn, edipi, participant_id, mhv_ids, vha_facility_ids)
  path = File.join('config', 'betamocks', 'cache', 'mvi', 'profile', "#{ssn}.yml")
  yaml = YAML.load(File.read(path))
  xml = yaml.dig(:body).dup.prepend('<?xml version="1.0" encoding="UTF-8"?>') unless xml =~ /^<\?xml/
  doc = Ox.load(xml)

  el = doc.locate(
    'env:Envelope/env:Body/idm:PRPA_IN201306UV02/controlActProcess/subject/registrationEvent/subject1/patient'
  ).first

  current_ids = MVI::Responses::IdParser.new.parse(el.locate('id'))

  el.nodes.delete_if do |n|
    [
      MVI::Responses::IdParser::CORRELATION_ROOT_ID,
      MVI::Responses::IdParser::EDIPI_ROOT_ID
    ].include? n.attributes[:root]
  end

  new_ids = {
    icn: icn, edipi: edipi, participant_id: participant_id,
    mhv_ids: mhv_ids, vha_facility_ids: vha_facility_ids
  }
  new_ids.reject! { |_, v| v.nil? }
  current_ids.merge!(new_ids)

  el.nodes << create_element(current_ids[:icn], :correlation, "%s^NI^200M^USVHA^P")
  el.nodes << create_element(current_ids[:edipi], :edipi, "%s^NI^200DOD^USDOD^A")
  el.nodes << create_element(current_ids[:participant_id], :correlation, "%s^PI^200CORP^USVBA^A")
  el.nodes.concat create_multiple_elements(current_ids[:mhv_ids], "%s^PI^200MH^USVHA^A")
  el.nodes.concat create_multiple_elements(current_ids[:vha_facility_ids], "123456^PI^%s^USVHA^A")

  yaml[:body] = Ox.dump(doc)
  File.open(path, 'w') { |f| f.write(yaml.to_yaml) }
end

def create_element(id, type, pattern)
  el = create_root_id(type)
  el[:extension] = pattern % id
  el
end

def create_multiple_elements(ids, pattern)
  ids.map { |id| create_element(id, :correlation, pattern) }
end

def create_root_id(type)
  el = Ox::Element.new('id')
  edipi_root = MVI::Responses::IdParser::EDIPI_ROOT_ID
  correlation_root = MVI::Responses::IdParser::CORRELATION_ROOT_ID
  el[:root] = (type == :edipi) ? edipi_root : correlation_root
  el
end

def create_cache_from_profile(cache_file, profile, template)
  xml = template.render!({ 'profile' => profile.as_json.stringify_keys })

  response = {
    method: :post,
    body: xml,
    headers: {
      connection: 'close',
      date: Time.now.utc.strftime('%a, %d %b %Y %H:%M:%S %Z'),
      'content-length' => xml.bytesize,
      'content-type' => 'text/xml',
      'set-cookie' => '',
      'x-powered-by' => 'Servlet/2.5 JSP/2.1'
    }
  }

  File.open(cache_file, 'w') { |f| f.write(response.to_yaml) }
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
