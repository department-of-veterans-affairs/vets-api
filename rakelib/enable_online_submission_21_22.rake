# frozen_string_literal: true

namespace :vso do
  # rubocop:disable Naming/VariableNumber
  desc 'Enable online submission of VA Form 21-22 for the given POA code(s)'
  task :enable_online_submission_21_22, [:poa_codes] => :environment do |_t, args|
    # rubocop:disable Layout/LineLength
    if args[:poa_codes].blank?
      raise ArgumentError,
            'Please provide POA codes (comma-separated). Example: rake vso:enable_online_submission_21_22["YHZ,SVS,A1Q"]'
    end
    # rubocop:enable Layout/LineLength

    # Parse and normalize input codes
    poa_codes = args[:poa_codes].split(',').map(&:strip).uniq

    puts "Received POA codes: #{poa_codes.join(', ')}"

    matching_orgs = Veteran::Service::Organization.where(poa: poa_codes)

    if matching_orgs.empty?
      raise StandardError, "No matching organizations found for provided POA codes: #{poa_codes.join(', ')}"
    end

    puts "Found #{matching_orgs.size} matching organization(s). Enabling online submission..."

    # rubocop:disable Rails/SkipsModelValidations
    updated = matching_orgs.update_all(can_accept_digital_poa_requests: true)
    # rubocop:enable Rails/SkipsModelValidations

    puts "Successfully updated #{updated} organization(s)."
  end
  # rubocop:enable Naming/VariableNumber
end
