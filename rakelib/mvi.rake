# frozen_string_literal: true

require 'csv'
require 'mpi/models/mvi_profile'
require 'identity/parsers/gc_ids'

namespace :mvi do
  desc 'Given user attributes, run a find candidate query'
  task find: :environment do
    unless valid_user_vars
      raise(
        ArgumentError,
        'Run the task with all required attributes: bundle exec rake mvi:find first_name="John" middle_name="W" ' \
        'last_name="Smith" birth_date="1945-01-25" gender="M" ssn="555443333"'
      )
    end

    begin
      uuid = SecureRandom.uuid

      identity = UserIdentity.new(
        uuid:,
        first_name: ENV.fetch('first_name', nil),
        middle_name: ENV.fetch('middle_name', nil),
        last_name: ENV.fetch('last_name', nil),
        birth_date: ENV.fetch('birth_date', nil),
        gender: ENV.fetch('gender', nil),
        ssn: ENV.fetch('ssn', nil),
        email: 'foo@bar.com',
        loa: {
          current: LOA::THREE,
          highest: LOA::THREE
        }
      )

      identity.save

      user = User.new(
        uuid:,
        identity:
      )

      user.last_signed_in = Time.now.utc
      pp MPIData.for_user(user).profile
    rescue => e
      puts "User query failed: #{e.message}"
    end
  end

  desc 'Given a CSV with ICNs, append attributes needed to stage the user as ID.me LOA3' do
    task :idme_saml_stage_attributes, [:csvfile] => [:environment] do |_, args|
      raise 'No input CSV provided' unless args[:csvfile]

      CSV.open("#{args[:csvfile]}.out", 'w', write_headers: true) do |dest|
        existing_headers = CSV.open(args[:csvfile], &:readline)
        appended_headers = %w[first_name middle_name last_name gender birth_date ssn address]
        CSV.open(args[:csvfile], headers: true) do |source|
          dest << (existing_headers + appended_headers)
          source.each do |row|
            user_identity = UserIdentity.new(
              uuid: SecureRandom.uuid,
              email: 'fakeemail@needed_for_object_validation.gov',
              mhv_icn: row['icn'], # HACK: because the presence of this attribute results in ICN based MVI lookup
              loa: {
                current: LOA::THREE,
                highest: LOA::THREE
              }
            )

            # Not persisting any users, user_identities, or caching MVI by doing it this way.
            user = User.new(uuid: user_identity.uuid)
            user.instance_variable_set(:@identity, user_identity)
            mpi = MPIData.for_user(user)
            response = mpi.send(:mpi_service).find_profile_by_identifier(identifier: user_identity.mhv_icn,
                                                                         identifier_type: MPI::Constants::ICN)

            appended_headers.each do |column_name|
              case column_name
              when 'address'
                row['address'] = response.profile.address.to_json
              when 'first_name'
                row['first_name'] = response.profile.given_names.first
              when 'middle_name'
                row['middle_name'] = response.profile.given_names.to_a[1..]&.join(' ')
              when 'last_name'
                row['last_name'] = response.profile.family_name
              else
                row[column_name] = response.profile.send(column_name.to_sym)
              end
            end

            dest << row
          end
        end
      end
    end
  end

  desc 'Build mock MVI yaml database for users in given CSV'
  task :mock_database, [:csvfile] => [:environment] do |_, args|
    raise 'No input CSV provided' unless args[:csvfile]

    csv = CSV.open(args[:csvfile], headers: true)
    csv.each_with_index do |row, i|
      bd = Time.iso8601(row['birth_date']).strftime('%Y-%m-%d')
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
      unless user.mpi_profile?
        puts "Row #{i} #{row['first_name']} #{row['last_name']}: No MVI profile"
        next
      end
    rescue => e
      puts "Row #{i} #{row['first_name']} #{row['last_name']}: #{e.message}"
    end
  end

  desc "Given a ssn update a mocked user's correlation ids"
  task update_ids: :environment do
    ssn = ENV.fetch('ssn', nil)
    raise ArgumentError, 'ssn is required, usage: `rake mvi:update_ids ssn=111223333 icn=abc123`' unless ssn

    ids = {}
    ids['icn'] = ENV.fetch('icn', nil)
    ids['edipi'] = ENV.fetch('edipi', nil)
    ids['participant_id'] = ENV.fetch('participant_id', nil)
    ids['mhv_ids'] = ENV['mhv_ids']&.split
    ids['vha_facility_ids'] = ENV['vha_facility_ids']&.split
    # 5343578988
    if ids.values.all?(&:nil?)
      message = 'at least one correlation id is required, e.g. `rake mvi:update_ids ssn=111223333 icn=abc123`'
      raise ArgumentError, message
    end

    path = File.join(Settings.betamocks.cache_dir, 'mvi', 'profile', "#{ssn}.yml")
    yaml = YAML.safe_load(File.read(path))
    xml = yaml[:body].dup.prepend('<?xml version="1.0" encoding="UTF-8"?>') unless xml.match?(/^<\?xml/)

    yaml[:body] = update_ids(xml, ids)
    File.write(path, yaml.to_yaml)

    puts 'ids updated!'
  end

  desc 'Create missing cache files from mock_mvi_responses.yml'
  task migrate_mock_data: :environment do
    yaml = YAML.safe_load(
      File.read(File.join('config', 'mvi_schema', 'mock_mvi_responses.yml'))
    )
    template = Liquid::Template.parse(
      File.read(File.join('config', 'mvi_schema', 'mvi_template.xml'))
    )
    yaml['find_candidate'].each do |k, v|
      cache_file = File.join(Settings.betamocks.cache_dir, 'mvi', 'profile', "#{k}.yml")
      unless File.exist? cache_file
        puts "user with ssn #{k} not found, generating cache file"
        profile = MPI::Models::MviProfile.new(v)
        create_cache_from_profile(cache_file, profile, template)
      end
    end

    puts 'cache files migrated!'
  end
end

def update_ids(xml, ids)
  doc = Ox.load(xml)

  el = doc.locate(
    'env:Envelope/env:Body/idm:PRPA_IN201306UV02/controlActProcess/subject/registrationEvent/subject1/patient'
  ).first

  temp_parse_class = Class.new { extend Identity::Parsers::GCIds }
  current_ids = temp_parse_class.parse_xml_gcids(el.locate('id'))
  current_ids[:participant_id] = current_ids[:vba_corp_id]

  el.nodes.delete_if do |n|
    [Identity::Parsers::GCIds::VA_ROOT_OID, Identity::Parsers::GCIds::DOD_ROOT_OID].include? n.attributes[:root]
  end

  new_ids = {
    icn: ids['icn'], edipi: ids['edipi'], participant_id: ids['participant_id'],
    mhv_ids: ids['mhv_ids'], vha_facility_ids: ids['vha_facility_ids']
  }

  new_ids.compact!
  current_ids.merge!(new_ids)

  updated_ids_element(current_ids, el)
  Ox.dump(doc)
end

def updated_ids_element(ids, el)
  el.nodes << create_element(ids[:icn], :correlation, '%s^NI^200M^USVHA^P') if ids[:icn]
  el.nodes << create_element(ids[:edipi], :edipi, '%s^NI^200DOD^USDOD^A') if ids[:edipi]
  el.nodes << create_element(ids[:participant_id], :correlation, '%s^PI^200CORP^USVBA^A') if ids[:participant_id]
  el.nodes.concat create_multiple_elements(ids[:mhv_ids], '%s^PI^200MH^USVHA^A') if ids[:mhv_ids]
  el.nodes.concat create_multiple_elements(ids[:vha_facility_ids], '123456^PI^%s^USVHA^A') if ids[:vha_facility_ids]
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
  edipi_root = Identity::Parsers::GCIds::DOD_ROOT_OID
  correlation_root = Identity::Parsers::GCIds::VA_ROOT_OID
  el[:root] = type == :edipi ? edipi_root : correlation_root
  el
end

def create_cache_from_profile(cache_file, profile, template)
  xml = template.render!('profile' => profile.as_json.stringify_keys)
  xml = update_ids(xml, profile.as_json)

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
    },
    status: 200
  }

  File.write(cache_file, response.to_yaml)
end

def valid_user_vars
  date_valid = validate_date(ENV.fetch('birth_date', nil))
  name_valid = ENV.fetch('first_name', nil) && ENV.fetch('middle_name', nil) && ENV.fetch('last_name', nil)
  attrs_valid = ENV.fetch('gender', nil) && ENV.fetch('ssn', nil)
  date_valid && name_valid && attrs_valid
end

def validate_date(s)
  raise ArgumentError, 'Date string must be of format YYYY-MM-DD' unless s.match?(/\d{4}-\d{2}-\d{2}/)

  Time.parse(s).utc
  true
rescue => e
  puts e.message
  false
end
