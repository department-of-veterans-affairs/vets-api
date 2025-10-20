# frozen_string_literal: true

namespace :vso do
  # rubocop:disable Naming/VariableNumber
  desc 'Enable online submission of VA Form 21-22 for matching VSOs'
  task enable_online_submission_21_22: :environment do
    rep_codes = Veteran::Service::Representative
                .pluck(:poa_codes)
                .flatten
                .compact
                .uniq

    puts "Found #{rep_codes.size} unique POA code(s) from representatives."

    matching_orgs = Veteran::Service::Organization.where(poa: rep_codes)

    if matching_orgs.empty?
      puts 'No matching organizations found.'
      next
    end

    puts "Found #{matching_orgs.size} matching organization(s). Enabling online submission..."

    # rubocop:disable Rails/SkipsModelValidations
    matching_orgs.update_all(can_accept_digital_poa_requests: true)
    # rubocop:enable Rails/SkipsModelValidations
  end
  # rubocop:enable Naming/VariableNumber
end
