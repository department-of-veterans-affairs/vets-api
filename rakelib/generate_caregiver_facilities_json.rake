# frozen_string_literal: true

require 'pdf_forms'

namespace :caregivers do
  desc 'description'
  task :generate_facilities_json, [] => :environment do
    generate
  end

  def generate
    puts 'Calling Lighthouse facilities api'
    Rails.logger.info("Job started with #{HealthFacility.count} existing health facilities.")
    facilities_from_lighthouse = get_facilities_from_lighthouse
    puts "Found #{facilities_from_lighthouse.count} faciliies."
    facilities_by_state = format_json_facilities(facilities_from_lighthouse)
    puts 'Formatting facilities and sorting by state'
    generate_json_file(facilities_by_state)
  rescue => e
    puts "Error occurred in #{self.class.name}: #{e.message}"
  end

  def get_facilities_from_lighthouse
    facilities_client = FacilitiesApi::V2::Lighthouse::Client.new
    all_facilities = []
    page = 1
    per_page = 1000

    loop do
      facilities = facilities_client.get_facilities(type: 'health', per_page:, page:,
                                                    services: ['CaregiverSupport'])
      all_facilities.concat(facilities.map do |facility|
        {
          code: facility.id.sub(/^vha_/, ''), # Transform id by stripping "vha_" prefix
          label: facility.name,
          state: facility.address&.dig('physical', 'state') || ''
        }
      end)

      break if facilities.size < per_page # Stop when we get less than per_page results

      page += 1
    end

    all_facilities
  end

  def format_json_facilities(facilities)
    # Group facilities by state
    formatted_facilities = facilities
                           .group_by { |facility| facility[:state] } # Group by state
                           .transform_values do |facilities_in_state|
      facilities_in_state
        .sort_by { |facility| facility[:code] } # Sort by code
        .map { |facility| { code: facility[:code], label: facility[:label] } } # Remove state key
    end

    formatted_facilities.sort.to_h # alphabetize states
  end

  def generate_json_file(facilities_by_state)
    formatted_data = JSON.pretty_generate(facilities_by_state)

    # Generate output file name
    output_file = 'caregiverProgramFacilities.json'
    FileUtils.mkdir_p(File.dirname(output_file)) # Ensure directory exists

    # Write the extracted data to a file
    File.write(output_file, formatted_data)
    puts "✅ Extracted PDF fields saved to: #{File.expand_path(output_file)}"
  end
end
