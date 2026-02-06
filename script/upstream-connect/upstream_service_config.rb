#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'optparse'

# Service configuration for upstream connections
class UpstreamServiceConfig # rubocop:disable Metrics/ClassLength
  # MPI service configuration
  MPI_SERVICE = {
    port: 4434,
    instructions: <<~TEXT
      MPI Connection instructions:

      For MPI, we must make the following TEMPORARY changes:
      1. In lib/common/client/configuration/soap.rb, adjust `#allow_missing_certs?` to return true
      2. In lib/mpi/configuration.rb, adjust `#ssl_options` to return `{ verify: false }`
    TEXT
  }.freeze

  # Service definitions with their required settings and ports
  SERVICES = {
    'appeals' => {
      name: 'Appeals (Caseflow)',
      description: 'Connect to Caseflow (Appeals) system',
      ports: [4437],
      settings_namespaces: ['caseflow'],
      skipped_settings: [[]],
      tunnel_setting: ['host'],
      mock_mpi: true,
      instructions: <<~TEXT
        Caseflow Connection Instructions:

        1. No additional steps needed.

        Test Connection:
          - Health Check: https://localhost:4437/health-check
          - Test User: vets.gov.user+0@gmail.com (Hector) <TODO no longer valid?>
          - Endpoints: /mobile/v0/appeal/:id, A6223

      TEXT
    },
    'awards' => {
      name: 'Benefits Eligibility Platform (BEP/BGS)',
      aliases: %w[payment_history bep bgs dependents],
      description: 'Connect to Benefits Eligibility Platform for awards and payment history data',
      ports: [4447],
      settings_namespaces: ['bgs'],
      skipped_settings: [['ssl_verify_mode']],
      tunnel_setting: ['url'],
      mock_mpi: false,
      instructions: <<~TEXT
        BEP/BGS Connection Instructions:

        Update Local Settings with SSL setting:
        ```
        # config/settings.local.yml

        bgs:
        ssl_verify_mode: none
        ```

        Test Connection:
        - Test User: vets.gov.user+137@gmail.com (Martin)
        - Endpoints: /mobile/v0/awards <TODO: data parsing issue?>
                     /mobile/v0/dependents
                     /mobile/v0/payment_history

      TEXT
    },
    'benefits_intake' => {
      name: 'Benefits Intake API (Lighthouse)',
      description: 'Connect to VA Benefits Intake API for backup 686c submissions? (TODO)',
      ports: [4492],
      settings_namespaces: ['lighthouse.benefits_intake'],
      skipped_settings: [['api_key']],
      tunnel_setting: ['host'],
      instructions: <<~TEXT
        Benefits Intake API Connection Instructions:

        (One-time setup)
        1. Generate Public key/JWK: https://developer.va.gov/explore/api/benefits-intake/client-credentials
          - Same key can be used for all Lighthouse Health APIs
        2. Sign up for VA Benefits Intake API Sandbox access and retrieve credentials.
          - https://developer.va.gov/explore/api/benefits-intake/sandbox-access
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
          - Test User: <Test Case Needed>
          - Endpoints: <Test Case Needed>

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
        1. Generate Public key/JWK: https://developer.va.gov/explore/api/benefits-claims/client-credentials
          - Same key can be used for all Lighthouse Health APIs
        2. Sign up for VA Benefits Claims API Sandbox access and retrieve credentials.
          - https://developer.va.gov/explore/api/benefits-claims/sandbox-access
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
          - Endpoints: /mobile/v0/claims-and-appeals-overview?
                       /mobile/v0/claim/:id, id: 600810891

        Additional Notes:
        - See the Lighthouse documentation for more info
          - https://developer.va.gov/explore/api/benefits-claims
      TEXT
    },
    'decision_letters' => {
      name: 'Benefits Documents API (Lighthouse)',
      aliases: %w[benefits_documents],
      description: 'Connect to VA Benefits Documents API for decision letters and doc uploads',
      ports: [4492],
      settings_namespaces: ['lighthouse.benefits_documents'],
      skipped_settings: [['timeout']],
      tunnel_setting: ['host'],
      mock_mpi: false,
      instructions: <<~TEXT
        Benefits Documents API Connection Instructions:

        (One-time setup)
        1. Generate Public key/JWK: https://developer.va.gov/explore/api/benefits-documents/client-credentials
          - Same key can be used for all Lighthouse Health APIs
        2. Sign up for VA Benefits Documents API Sandbox access and retrieve credentials.
          - https://developer.va.gov/explore/api/benefits-documents/sandbox-access
        3. Update Local Settings with client_id and rsa_key:
          ```
          # config/settings.local.yml

          lighthouse:
            auth:
              ccg:
                client_id: 'your-client-id'
                rsa_key: your/path/to/private.pem # e.g. config/certs/lighthouse/private.pem
          ```

        Test Connection:
          - Test User: judy.morrison@id.me
          - Endpoints: /mobile/v0/claims/decision-letters

        Additional Notes:
        - See the Lighthouse documentation for more info
          - https://developer.va.gov/explore/api/benefits-documents
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
        1. Generate Public key: https://developer.va.gov/explore/api/direct-deposit-management/client-credentials
          - Same key can be used for all Lighthouse Health APIs
        2. Sign up for Direct Deposit Management API Sandbox access and retrieve credentials.
          - https://developer.va.gov/explore/api/direct-deposit-management/sandbox-access
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
          - Test User: <TODO Test Case Needed>
          - Endpoints: /mobile/v0/payment-information/benefits

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
      mock_mpi: true,
      instructions: <<~TEXT
        Patient Health API Connection Instructions:

        (One-time setup)
        1. Generate Public key/JWK: https://developer.va.gov/explore/api/patient-health/client-credentials
          - Same key can be used for all Lighthouse Health APIs
        2. Sign up for Patient Health API Sandbox access and retrieve credentials.
          - https://developer.va.gov/explore/api/patient-health/sandbox-access
        3. Update Local Settings with client_id and key_path:
          ```
          # config/settings.local.yml

          lighthouse_health_immunization:
            client_id: 'your-client-id'
            key_path: your/path/to/private.pem # e.g. config/certs/lighthouse/private.pem
          ```
        4. Update Local Settings to use localhost (LH sandbox) instead of fwdproxy (LH staging):
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
          - Endpoints: /mobile/v0/health/immunizations
                       /mobile/v0/health/locations/:id, id: <TODO>


        Additional Notes:
        - See the Lighthouse documentation for more info
          - https://developer.va.gov/explore/api/patient-health
      TEXT
    },
    'labs_and_tests' => {
      name: 'Patient Health API (FHIR) (Lighthouse)',
      aliases: ['allergies_v0'],
      description: 'Search for an individual patients appointments, conditions, medications, observations including vital signs and lab tests, and more.', # rubocop:disable Layout/LineLength
      ports: [4492],
      settings_namespaces: ['lighthouse.veterans_health'],
      skipped_settings: [['fast_tracker.api_key', 'fast_tracker.client_id']],
      tunnel_setting: ['url'],
      mock_mpi: true,
      instructions: <<~TEXT
        Patient Health API Connection Instructions:

        (One-time setup)
        1. Generate Public key/JWK: https://developer.va.gov/explore/api/patient-health/client-credentials
          - Same key can be used for all Lighthouse Health APIs
        2. Sign up for Patient Health API Sandbox access and retrieve credentials.
          - https://developer.va.gov/explore/api/patient-health/sandbox-access
        3. Update Local Settings with client_id and api_key:
          ```
          # config/settings.local.yml

          lighthouse:
            veterans_health:
              fast_tracker:
                api_key: your/path/to/private.pem # e.g. config/certs/lighthouse/private.pem
                client_id: 0oaaxkp0aeXEJkMFw2p7
          ```

        Test Connection:
          - Test User: judy.morrison@id.me
          - Endpoints: /mobile/v0/health/allergy-intolerances
                       /mobile/v0/health/labs-and-tests

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
        1. Generate Public key/JWK: https://developer.va.gov/explore/api/va-letter-generator/client-credentials
          - Same key can be used for all Lighthouse Health APIs
        2. Sign up for VA Letter Generator API Sandbox access and retrieve credentials.
          - https://developer.va.gov/explore/api/va-letter-generator/sandbox-access
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
          - Endpoints: /mobile/v0/letters

        Additional Notes:
        - See the Lighthouse documentation for more info
          - https://developer.va.gov/explore/api/va-letter-generator
      TEXT
    },
    'user' => {
      name: 'MPI',
      aliases: %w[mpi],
      description: 'Connect to MVI for user identity data',
      ports: [4492],
      settings_namespaces: ['lighthouse.facilities'],
      skipped_settings: [[]],
      tunnel_setting: ['url'],
      mock_mpi: false,
      instructions: <<~TEXT
        MPI Connection Instructions:

        1. Run `upstream-connect` for `va_profile` as well if requesting `/v0/user`

        Test Connection:
          - Test User: judy.morrison@id.me
          - Endpoints: /mobile/v0/user
                       /mobile/v0/user/authorized-services
      TEXT
    },
    'va_profile' => {
      name: 'VA Profile',
      aliases: %w[contact_info demographics military_personnel military_service addresses emails phones preferred_name],
      description: 'Connect to VA Profile for user profile, contact info, and military service history data',
      ports: [4433],
      settings_namespaces: ['va_profile'],
      skipped_settings: [%w[address_validation v3]],
      tunnel_setting: ['url'],
      mock_mpi: false, # While MPI is not required for these calls, it is often used in conjunction with the MPI config. This prevents conflicting MPI port settings # rubocop:disable Layout/LineLength
      instructions: <<~TEXT
        VA Profile Connection Instructions:

        1. To connect to VA Profile (QA), TEMPORARILY
          update `SETTINGS` in `lib/va_profile/configuration.rb` to `SETTINGS = Settings.va_profile`

        Test Connection:
          - Test User: judy.morrison@id.me
          - Endpoints: GET /mobile/v0/user/contact-info
                       GET /mobile/v0/user/demographics
                       GET /mobile/v0/user/military-service-history
                       POST /mobile/v0/phones
      TEXT
    },
    'vet_verification' => {
      name: 'Vet Service History and Eligibility API (Lighthouse)',
      aliases: ['disability_rating'],
      description: 'Connect to Vet Service History and Eligibility API for the service history, certain enrolled benefits, and disability rating information of a veteran', # rubocop:disable Layout/LineLength
      ports: [4492], # Judy has information for LH staging, i.e. 4475
      settings_namespaces: ['lighthouse.veteran_verification'],
      skipped_settings: [['form526.access_token', 'status']],
      tunnel_setting: ['host'],
      instructions: <<~TEXT
        Vet Service History and Eligibility API Connection Instructions:

        TODO

        (One-time setup)
        1. Generate Public key/JWK: https://developer.va.gov/explore/api/veteran-service-history-and-eligibility/client-credentials
          - Same key can be used for all Lighthouse Health APIs
        2. Sign up for Vet Service History and Eligibility API Sandbox access and retrieve credentials.
          - https://developer.va.gov/explore/api/veteran-service-history-and-eligibility/sandbox-access
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
          - Test User: <Need good test case>
          - Endpoints: /mobile/v0/disability_rating
                       /mobile/v0/vet_verification_status

        Additional Notes:
        - See the Lighthouse documentation for more info
          - https://developer.va.gov/explore/api/veteran-service-history-and-eligibility
      TEXT
    }
  }.freeze

  def self.resolve_service_name(service_name)
    # Check if it's a main service key
    return service_name if SERVICES.key?(service_name)

    # Check if it's an alias
    SERVICES.each do |key, config|
      return key if config[:aliases]&.include?(service_name)
    end

    nil
  end

  def initialize
    @options = {}
  end

  def run
    parse_options

    case @options[:action]
    when :list
      list_services
    when :service_keys
      list_service_keys
    when :validate
      validate_service(@options[:service])
    when :config
      show_service_config(@options[:service])
    when :mpi_instructions
      show_mpi_instructions
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

      opts.on('--mpi-instructions', 'Get MPI setup instructions') do
        @options[:action] = :mpi_instructions
      end

      opts.on('--check-settings', 'Check which services have settings present in local config') do
        @options[:action] = :check_settings
      end

      opts.on('-h', '--help', 'Show this help message') do
        puts opts
        exit
      end
    end

    # Handle internal flags after parsing to avoid showing in help
    # --service-keys is used internally by the shell script but not documented for users
    if ARGV.include?('--service-keys')
      @options[:action] = :service_keys
      ARGV.delete('--service-keys')
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

  def list_service_keys
    puts SERVICES.keys.join("\n")
  end

  def format_services_list
    SERVICES.map do |key, config|
      # Build service name line with aliases using ANSI color codes
      # Bold blue for main service, lighter blue for aliases
      name_line = "\033[1;34m#{key}\033[0m" # Bold blue for main service
      if config[:aliases] && !config[:aliases].empty? # rubocop:disable Rails/Present
        aliases_colored = config[:aliases].map { |alias_name| "\033[36m#{alias_name}\033[0m" }.join(' | ')
        name_line += " | #{aliases_colored}"
      end

      # Add description on next line with subtle gray color
      "#{name_line}\n\033[37m#{config[:description]}\033[0m"
    end.join("\n\n")
  end

  def validate_service(service_name)
    resolved_service = resolve_service_name(service_name)

    unless resolved_service
      puts "Error: Unknown service '#{service_name}'"
      puts ''
      puts 'Available services:'
      puts format_services_list
      exit 1
    end

    puts "Service '#{service_name}' is valid"
  end

  def show_service_config(service_name)
    resolved_service = resolve_service_name(service_name)

    unless resolved_service
      puts "Error: Unknown service '#{service_name}'"
      exit 1
    end

    config = SERVICES[resolved_service]

    # Convert to a format suitable for shell script consumption
    output = {
      name: config[:name],
      description: config[:description],
      settings_namespaces: config[:settings_namespaces],
      ports: config[:ports],
      tunnel_setting: config[:tunnel_setting],
      skipped_settings: config[:skipped_settings],
      mock_mpi: config.key?(:mock_mpi) ? config[:mock_mpi] : true,
      instructions: config[:instructions]&.strip
    }

    puts JSON.pretty_generate(output)
  end

  def show_mpi_instructions
    puts MPI_SERVICE[:instructions].strip
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

  def resolve_service_name(service_name)
    # Check if it's a main service key
    return service_name if SERVICES.key?(service_name)

    # Check if it's an alias
    SERVICES.each do |key, config|
      return key if config[:aliases]&.include?(service_name)
    end

    nil
  end
end

# Run the script if called directly
UpstreamServiceConfig.new.run if __FILE__ == $PROGRAM_NAME
