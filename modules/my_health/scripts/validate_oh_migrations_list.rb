#!/usr/bin/env ruby
# frozen_string_literal: true

# Standalone script to validate oh_migrations_list settings format
# Uses the actual MigrationsParser to prevent drift.
#
# Usage:
#   ruby modules/my_health/scripts/validate_oh_migrations_list.rb "2026-04-11:[983,Test 1]"
#   ruby modules/my_health/scripts/validate_oh_migrations_list.rb  # (reads from settings.local.yml)
#
# Valid format:
#   DATE:[FACILITY_ID,FACILITY_NAME];DATE:[FACILITY_ID,FACILITY_NAME],...
#
# Examples:
#   Valid:   2026-04-11:[983,Test 1]
#   Valid:   2026-04-11:[983,Test 1];2026-03-11:[984,Test 2]
#   Valid:   2026-04-11:[983,Facility A],[984,Facility B];2026-05-01:[985,Facility C]

require 'date'
require 'yaml'

# Load the actual parser (single source of truth)
require_relative '../../../lib/mhv/oh_facilities_helper/migrations_parser'

def print_result(parser, parsed_data)
  puts "\n#{'=' * 60}"

  if parser.errors.empty?
    puts "✅ VALID"
    puts '=' * 60
    puts "\nParsed #{parsed_data.length} migration schedule(s):\n\n"

    parsed_data.each_with_index do |migration, index|
      puts "  Migration ##{index + 1}:"
      puts "    Date: #{migration[:migration_date]}"
      puts "    Facilities:"
      migration[:facilities].each do |facility|
        puts "      - ID: #{facility[:id]}, Name: #{facility[:name]}"
      end
      puts
    end
  else
    puts "❌ INVALID"
    puts '=' * 60
    puts "\nFound #{parser.errors.length} error(s):\n\n"

    parser.errors.each_with_index do |error, index|
      puts "  #{index + 1}. #{error}"
    end
    puts
  end
end

def load_from_settings
  settings_path = File.expand_path('../../../config/settings.local.yml', __dir__)

  unless File.exist?(settings_path)
    puts "Error: settings.local.yml not found at #{settings_path}"
    exit 1
  end

  settings = YAML.load_file(settings_path)
  settings.dig('mhv', 'oh_facility_checks', 'oh_migrations_list')
end

# Main execution
if __FILE__ == $PROGRAM_NAME
  input = if ARGV.empty?
            puts 'No argument provided, reading from config/settings.local.yml...'
            load_from_settings
          else
            ARGV[0]
          end

  puts "\nValidating: #{input.inspect}"

  parser = MHV::OhFacilitiesHelper::MigrationsParser.new(input)
  parsed_data = parser.parse

  print_result(parser, parsed_data)

  exit(parser.errors.empty? ? 0 : 1)
end
