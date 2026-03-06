# frozen_string_literal: true

namespace :vso do
  desc 'Enable individual acceptance of VA Form 21-22 for the given POA code(s)'

  # Usage:
  #   # Single POA
  #   bundle exec rake "vso:enable_individual_acceptance[072]"
  #
  #   # Multiple POAs (comma-separated in a single arg)
  #   bundle exec rake "vso:enable_individual_acceptance[072,083]"
  #
  # Notes:
  #   - POA codes are normalized by the service (splits commas, strips whitespace, de-dupes).
  task :enable_individual_acceptance, [:poa_codes] => :environment do |_t, args|
    raise ArgumentError, 'POA codes required (comma-separated)' if args[:poa_codes].blank?

    poa_codes = [args[:poa_codes], *args.extras].compact.uniq

    Rails.logger.tagged('rake:vso:enable_individual_acceptance') do
      Rails.logger.info("Received POA codes: #{poa_codes.join(', ')}")
      Rails.logger.info('Enabling individual acceptance for matching organization(s)...')

      result = AccreditedRepresentativePortal::EnableIndividualAcceptance2122Service.call(poa_codes:)

      Rails.logger.info(
        "Set acceptance_mode=self_only for #{result[:reps_updated]} " \
        'active rep-org relationship(s).'
      )
    end
  end
end
