# frozen_string_literal: true

namespace :vso do
  desc 'Enable online submission of VA Form 21-22 for the given POA code(s)'
  task :enable_online_submission_for_vso, [:poa_codes] => :environment do |_t, args|
    raise ArgumentError, 'POA codes required (comma-separated)' if args[:poa_codes].blank?

    poa_codes = [args[:poa_codes], *args.extras].compact.uniq

    Rails.logger.tagged('rake:vso:enable_online_submission_for_vso') do
      Rails.logger.info("Received POA codes: #{poa_codes.join(', ')}")
      Rails.logger.info('Enabling online submission for matching organization(s)...')

      result = AccreditedRepresentativePortal::EnableOnlineSubmission2122Service.call(poa_codes:)

      Rails.logger.info("Enabled online submission for #{result} organization(s).")
    end
  end
end
