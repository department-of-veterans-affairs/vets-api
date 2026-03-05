# frozen_string_literal: true

namespace :vso do
  desc 'Disable online submission of VA Form 21-22 for the given POA code(s)'
  #
  # Usage:
  #   # Single POA:
  #   bundle exec rake "vso:disable_online_submission[083]"
  #
  #   # Multiple POAs (comma-separated in brackets):
  #   bundle exec rake "vso:disable_online_submission[083,074,095]"
  #
  task :disable_online_submission, [:poa_codes] => :environment do |_t, args|
    raise ArgumentError, 'POA codes required (comma-separated)' if args[:poa_codes].blank?

    poa_codes = [args[:poa_codes], *args.extras].compact.uniq

    Rails.logger.tagged('rake:vso:disable_online_submission') do
      Rails.logger.info("Received POA codes: #{poa_codes.join(', ')}")
      Rails.logger.info('Disabling online submission for matching organization(s)...')

      result = AccreditedRepresentativePortal::DisableOnlineSubmission2122Service.call(poa_codes:)

      Rails.logger.info("Disabled online submission for #{result[:orgs_updated]} organization(s).")
      Rails.logger.info(
        "Set acceptance_mode=no_acceptance for #{result[:reps_updated]} " \
        'active rep-org relationship(s).'
      )
    end
  end
end
