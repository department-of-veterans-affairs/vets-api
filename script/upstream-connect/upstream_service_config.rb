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
      settings_keys: ['caseflow'],
      skipped_settings: [[]],
      tunnel_setting: ['host'],
      instructions: <<~TEXT
        Appeals/Caseflow Connection Instructions:

        1. Your local vets-api will now connect to staging Caseflow
        2. Test the connection by visiting:
           - Caseflow API: http://localhost:4437/health-check

        3. In your vets-api console, you can test with:
           Caseflow::Service.new.get_appeals('some-user-id')

        Additional Notes:
        - Appeals data is sensitive - use test user IDs only
        - Staging Caseflow may have different data than production
      TEXT
    },
    'letters' => {
      name: 'Letters (Lighthouse Letters Generator)',
      description: 'Connect to Lighthouse Letters Generator API for letters',
      ports: [4492],
      settings_keys: ['lighthouse.letters_generator'],
      skipped_settings: [['access_token.client_id', 'access_token.rsa_key']],
      tunnel_setting: ['url'],
      instructions: <<~TEXT
        Letters Connection Instructions:

        1. Your local vets-api will now connect to staging Lighthouse Benefits Claims
        2. Test the connection by visiting:
           - Lighthouse API: http://localhost:4492/health

        3. In your vets-api console, you can test with:
           response = Lighthouse::BenefitsClaims::Service.new.get_letters('test-icn')

        Additional Notes:
        - Use staging test ICNs for testing
        - Letters API requires valid veteran identifiers
        - Check the Lighthouse documentation for available endpoints
      TEXT
    }
    # TODO: Add more services as needed
    # 'health_records' => {
    #   name: 'Health Records (FHIR)',
    #   description: 'Connect to FHIR health records API',
    #   settings_keys: ['lighthouse.fhir', 'mhv.medical_records'],
    #   ports: [4433, 4434],
    #   tunnel_setting: [],
    #   skipped_settings: [[], []],
    #   instructions: 'Instructions for health records connection...'
    # },
    # 'benefits' => {
    #   name: 'Benefits (BGS)',
    #   description: 'Connect to Benefits Gateway Service',
    #   settings_keys: ['bgs'],
    #   ports: [4435],
    #   tunnel_setting: [],
    #   skipped_settings: [[]],
    #   instructions: 'Instructions for BGS connection...'
    # }
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
    else
      show_usage
    end
  end

  private

  def parse_options
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
      settings_keys: config[:settings_keys],
      ports: config[:ports],
      tunnel_setting: config[:tunnel_setting],
      skipped_settings: config[:skipped_settings],
      instructions: config[:instructions]&.strip
    }

    puts JSON.pretty_generate(output)
  end
end

# Run the script if called directly
UpstreamServiceConfig.new.run if __FILE__ == $PROGRAM_NAME
