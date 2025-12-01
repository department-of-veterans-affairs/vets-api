#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'optparse'

# Service configuration for upstream connections
class UpstreamServiceConfig
  # Service definitions with their required settings and ports
  SERVICES = {
    'appeals' => {
      name: 'Appeals (Caseflow)',
      description: 'Connect to Caseflow appeals system',
      ports: [4437],
      settings_namespaces: ['caseflow'],
      skipped_settings: [[]],
      tunnel_setting: ['host'],
      instructions: <<~TEXT
        Appeals/Caseflow Connection Instructions:

        1. No additional steps needed.

        Test Connection:
          - Test User: vets.gov.user+0@gmail.com (Hector)
          - endpoint: /mobile/v0/appeal/:id, A6223

      TEXT
    },
    'allergies_v0' => {
      name: 'Patient Health API (FHIR) (Lighthouse)',
      aliases: ['labs_and_tests'],
      description: 'Search for an individual patients appointments, conditions, medications, observations including vital signs and lab tests, and more.', # rubocop:disable Layout/LineLength
      ports: [4492],
      settings_namespaces: ['lighthouse.veterans_health'],
      skipped_settings: [['fast_tracker.api_key', 'fast_tracker.client_id']],
      tunnel_setting: ['url'],
      instructions: <<~TEXT
        Patient Health API Connection Instructions:

        (One-time setup)
        1. Sign up for Patient Health API Sandbox access and retrieve credentials.
          - https://developer.va.gov/explore/api/patient-health/sandbox-access
        2. Generate Public key: https://developer.va.gov/explore/api/patient-health/client-credentials
        3. Update Local Settings with client_id and api_key:
          ```
          # config/settings.local.yml

          lighthouse:
            veterans_health:
              fast_tracker:
                api_key: /srv/vets-api/secret/lighthouse_fast_track_api.key
                client_id: 0oaaxkp0aeXEJkMFw2p7
          ```

        Test Connection:
          - Test User: judy.morrison@id.me
          - endpoint: /mobile/v0/health/allergy-intolerances

        Additional Notes:
        - See the Lighthouse documentation for more info
          - https://developer.va.gov/explore/api/patient-health
      TEXT
    },
    'dependents' => {
      name: 'Benefits Intake API (Lighthouse)',
      description: 'Connect to VA Benefits Intake API for dependents data',
      ports: [4492],
      settings_namespaces: ['lighthouse.benefits_intake'],
      skipped_settings: [['api_key']],
      tunnel_setting: ['host'],
      instructions: <<~TEXT
        Benefits Intake API Connection Instructions:

        (One-time setup)
        1. Sign up for VA Benefits Intake API Sandbox access and retrieve credentials.
          - https://developer.va.gov/explore/api/benefits-intake/sandbox-access
        2. Generate Public key: https://developer.va.gov/explore/api/benefits-intake/client-credentials
        3. Update Local Settings with client_id and rsa_key:
          ```
          # config/settings.local.yml

          lighthouse:
            benefits_claims:
              access_token:
                client_id: 'your-client-id'
                rsa_key: your/path/to/private.pem # e.g. config/certs/lighthouse/private.pem
          ```

        Test Connection:
          - Test User: judy.morrison@id.me
          - endpoint: /mobile/v0/dependents

        Additional Notes:
        - See the Lighthouse documentation for more info
          - https://developer.va.gov/explore/api/benefits-intake
      TEXT
    },
    'claims' => {
      name: 'Benefits Claims API (Lighthouse)',
      description: 'Connect to VA Benefits Claims API for claims data',
      ports: [4492],
      settings_namespaces: ['lighthouse.benefits_claims'],
      skipped_settings: [['access_token.client_id', 'access_token.rsa_key', 'form526']],
      tunnel_setting: ['host'],
      instructions: <<~TEXT
        Benefits Claims API Connection Instructions:

        (One-time setup)
        1. Sign up for VA Benefits Claims API Sandbox access and retrieve credentials.
          - https://developer.va.gov/explore/api/benefits-claims/sandbox-access
        2. Generate Public key: https://developer.va.gov/explore/api/benefits-claims/client-credentials
        3. Update Local Settings with client_id and rsa_key:
          ```
          # config/settings.local.yml

          lighthouse:
            benefits_claims:
              access_token:
                client_id: 'your-client-id'
                rsa_key: your/path/to/private.pem # e.g. config/certs/lighthouse/private.pem
          ```

        Test Connection:
          - Test User: judy.morrison@id.me
          - endpoint: /mobile/v0/claim/:id, id: 600810891

        Additional Notes:
        - See the Lighthouse documentation for more info
          - https://developer.va.gov/explore/api/benefits-claims
      TEXT
    },
    'direct_deposit' => {
      name: 'Direct Deposit Management API (Lighthouse)',
      description: 'Connect to VA Direct Deposit Management API for direct deposit abnking data',
      ports: [4492],
      settings_namespaces: ['lighthouse.direct_deposit'],
      skipped_settings: [['access_token.client_id', 'access_token.rsa_key', 'form526']],
      tunnel_setting: ['host'],
      instructions: <<~TEXT
        Direct Deposit Management API Connection Instructions:

        (One-time setup)
        1. Sign up for Direct Deposit Management API Sandbox access and retrieve credentials.
          - https://developer.va.gov/explore/api/direct-deposit-management/sandbox-access
        2. Generate Public key: https://developer.va.gov/explore/api/direct-deposit-management/client-credentials
        3. Update Local Settings with client_id and rsa_key:
          ```
          # config/settings.local.yml

          lighthouse:
            direct_deposit:
              access_token:
                client_id: 'your-client-id'
                rsa_key: your/path/to/private.pem # e.g. config/certs/lighthouse/private.pem
          ```

        Test Connection:
          - Test User: TBD
          - endpoint: /mobile/v0/payment-information/benefits

        Additional Notes:
        - See the Lighthouse documentation for more info
          - https://developer.va.gov/explore/api/direct-deposit-management
      TEXT
    },
    'immunizations' => {
      name: 'Immunizations/Locations - Patient Health API (FHIR) (Lighthouse)',
      aliases: ['locations'],
      description: 'Search for an individual patients immunizations and Location information',
      ports: [4492],
      settings_namespaces: ['lighthouse_health_immunization'],
      skipped_settings: [%w[client_id key_path scopes]],
      tunnel_setting: ['url'],
      instructions: <<~TEXT
        Patient Health API Connection Instructions:

        (One-time setup)
        1. Sign up for Patient Health API Sandbox access and retrieve credentials.
          - https://developer.va.gov/explore/api/patient-health/sandbox-access
        2. Generate Public key: https://developer.va.gov/explore/api/patient-health/client-credentials
        3. Update Local Settings with client_id and key_path:
          ```
          # config/settings.local.yml

          lighthouse_health_immunization:
            client_id: 'your-client-id'
            key_path: your/path/to/private.pem # e.g. config/certs/lighthouse/private.pem
          ```
        4. Update Local Settings to use localhost instead of fwdproxy
          ```
          # config/settings.local.yml

          lighthouse_health_immunization:
            access_token_url: https://fwdproxy-staging.vfs.va.gov:4492/oauth2/health/system/v1/token
            api_url: https://fwdproxy-staging.vfs.va.gov:4492/services/fhir/v0/r4

            <becomes>

            access_token_url: https://localhost:4492/oauth2/health/system/v1/token
            api_url: https://localhost:4492/services/fhir/v0/r4

          ```

        Test Connection:
          - Test User: judy.morrison@id.me
          - endpoint: /mobile/v0/health/immunizations
                      /mobile/v0/health/locations/:id, id: <unknown>
                      /mobile/v1/health/immunizations

        Additional Notes:
        - See the Lighthouse documentation for more info
          - https://developer.va.gov/explore/api/patient-health
      TEXT
    },
    'letters' => {
      name: 'Letter Generator API (Lighthouse)',
      description: 'Connect to VA Letter Generator API for official VA letters',
      ports: [4492],
      settings_namespaces: ['lighthouse.letters_generator'],
      skipped_settings: [['access_token.client_id', 'access_token.rsa_key']],
      tunnel_setting: ['url'],
      instructions: <<~TEXT
        Letter Generator API Connection Instructions:

        (One-time setup)
        1. Sign up for VA Letter Generator API Sandbox access and retrieve credentials.
          - https://developer.va.gov/explore/api/va-letter-generator/sandbox-access
        2. Generate Public key: https://developer.va.gov/explore/api/va-letter-generator/client-credentials
        3. Update Local Settings with client_id and rsa_key:
          ```
          # config/settings.local.yml

          lighthouse:
            letters_generator:
              access_token:
                client_id: 'your-client-id'
                rsa_key: your/path/to/private.pem # e.g. config/certs/lighthouse/private.pem
          ```

        Test Connection:
          - Test User: vets.gov.user+54@gmail.com
          - endpoint: /mobile/v0/letters

        Additional Notes:
        - See the Lighthouse documentation for more info
          - https://developer.va.gov/explore/api/va-letter-generator
      TEXT
    },
    'vet_verification' => {
      name: 'Vet Service History and Elegibility API (Lighthouse)',
      aliases: ['disability_rating'],
      description: 'Connect to Vet Service History and Elegibility API for the service history, certain enrolled benefits, and disability rating information of a veteran', # rubocop:disable Layout/LineLength
      ports: [4492],
      settings_namespaces: ['lighthouse.veteran_verification'],
      skipped_settings: [['form526.access_token', 'status']],
      tunnel_setting: ['host'],
      instructions: <<~TEXT
        Letter Generator API Connection Instructions:

        TODO

        (One-time setup)
        1. Sign up for Vet Service History and Elegibility API Sandbox access and retrieve credentials.
          - https://developer.va.gov/explore/api/veteran-service-history-and-eligibility/sandbox-access
        2. Generate Public key: https://developer.va.gov/explore/api/veteran-service-history-and-eligibility/client-credentials
        3. Update Local Settings with client_id and rsa_key:
          ```
          # config/settings.local.yml

          lighthouse:
            veteran_verification:
              form526:
                access_token:
                  client_id: 'your-client-id'
                  rsa_key: your/path/to/private.pem # e.g. config/certs/lighthouse/private.pem
          ```

        Test Connection:
          - Test User: Judy? TBD
          - endpoints: /mobile/v0/disability_rating
                       /mobile/v0/vet_verification_status

        Additional Notes:
        - See the Lighthouse documentation for more info
          - https://developer.va.gov/explore/api/veteran-service-history-and-eligibility
      TEXT
    }
  }.freeze

  def initialize
    @options = {}
  end

  def run
    parse_options

    case @options[:action]
    when :list
      list_services
    when :validate
      validate_service(@options[:service])
    when :config
      show_service_config(@options[:service])
    when :check_settings
      check_local_settings
    else
      show_usage
    end
  end

  private

  def parse_options # rubocop:disable Metrics/MethodLength
    parser = OptionParser.new do |opts|
      opts.banner = 'Usage: upstream_service_config.rb [options]'
      opts.separator ''
      opts.separator 'Service configuration helper for upstream connections'
      opts.separator ''
      opts.separator 'Options:'

      opts.on('--list', 'List all available services') do
        @options[:action] = :list
      end

      opts.on('--validate SERVICE', 'Validate that a service exists') do |service|
        @options[:action] = :validate
        @options[:service] = service
      end

      opts.on('--config SERVICE', 'Get configuration for a service (JSON)') do |service|
        @options[:action] = :config
        @options[:service] = service
      end

      opts.on('--check-settings', 'Check which services have settings present in local config') do
        @options[:action] = :check_settings
      end

      opts.on('-h', '--help', 'Show this help message') do
        puts opts
        exit
      end
    end

    parser.parse!
  rescue OptionParser::InvalidOption => e
    puts "Error: #{e.message}"
    puts parser
    exit 1
  end

  def show_usage
    puts 'Error: No action specified'
    puts ''
    puts 'Available actions:'
    puts '  --list                List all available services'
    puts '  --validate SERVICE    Validate that a service exists'
    puts '  --config SERVICE      Get configuration for a service'
    puts '  --check-settings      Check which services have settings present'
    exit 1
  end

  def list_services
    puts format_services_list
  end

  def format_services_list
    max_key_length = SERVICES.keys.map(&:length).max

    SERVICES.map do |key, config|
      "#{key.ljust(max_key_length)} - #{config[:name]}: #{config[:description]}"
    end.join("\n")
  end

  def validate_service(service_name)
    unless SERVICES.key?(service_name)
      puts "Error: Unknown service '#{service_name}'"
      puts ''
      puts 'Available services:'
      puts format_services_list
      exit 1
    end

    puts "Service '#{service_name}' is valid"
  end

  def show_service_config(service_name)
    unless SERVICES.key?(service_name)
      puts "Error: Unknown service '#{service_name}'"
      exit 1
    end

    config = SERVICES[service_name]

    # Convert to a format suitable for shell script consumption
    output = {
      name: config[:name],
      description: config[:description],
      settings_namespaces: config[:settings_namespaces],
      ports: config[:ports],
      tunnel_setting: config[:tunnel_setting],
      skipped_settings: config[:skipped_settings],
      instructions: config[:instructions]&.strip
    }

    puts JSON.pretty_generate(output)
  end

  def check_local_settings # rubocop:disable Metrics/MethodLength
    settings_file = File.expand_path('../../config/settings.local.yml', __dir__)

    unless File.exist?(settings_file)
      puts JSON.pretty_generate({ error: 'settings.local.yml not found' })
      return
    end

    begin
      require 'yaml'
      settings = YAML.load_file(settings_file) || {}

      results = {}

      SERVICES.each do |service_key, service_config|
        service_config[:settings_namespaces].each do |namespace|
          namespace_parts = namespace.split('.')
          value = get_nested_setting(settings, namespace_parts)

          results[namespace] = {
            service: service_key,
            present: !value.nil?,
            has_content: value.is_a?(Hash) && !value.empty?
          }
        end
      end

      puts JSON.pretty_generate(results)
    rescue => e
      puts JSON.pretty_generate({ error: "Failed to parse settings: #{e.message}" })
    end
  end

  def get_nested_setting(hash, keys)
    keys.reduce(hash) do |current, key|
      return nil unless current.is_a?(Hash)

      current[key] || current[key.to_sym]
    end
  end
end

# Run the script if called directly
UpstreamServiceConfig.new.run if __FILE__ == $PROGRAM_NAME
