# frozen_string_literal: true

namespace :vso do
  # rubocop:disable Naming/VariableNumber
  desc 'Enable online submission of VA Form 21-22 for the given POA code(s)'
  task :enable_online_submission_21_22, [:poa_codes] => :environment do |_t, args|
    raise ArgumentError, 'POA codes required (comma-separated)' if args[:poa_codes].blank?

    poa_codes = [args[:poa_codes], *args.extras].compact.uniq
    result = AccreditedRepresentativePortal::EnableOnlineSubmission2122Service.call(poa_codes:)

    Rails.logger.info("Received POA codes: #{result[:poa_codes].join(', ')}")
    Rails.logger.info("Found #{result[:matched_count]} matching organization(s). Enabling online submission")
    Rails.logger.info("Successfully updated #{result[:updated_count]} organization(s).")
  end
  # rubocop:enable Naming/VariableNumber
end
