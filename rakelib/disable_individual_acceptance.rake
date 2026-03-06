# frozen_string_literal: true

namespace :vso do
  desc 'Disable individual acceptance of VA Form 21-22 for the given POA code(s)'
  #
  # Usage:
  #   # Single POA:
  #   bundle exec rake "vso:disable_individual_acceptance[083]"
  #
  #   # Multiple POAs (comma-separated in brackets):
  #   bundle exec rake "vso:disable_individual_acceptance[083,074,095]"
  #
  task :disable_individual_acceptance, [:poa_codes] => :environment do |_t, args|
    raise ArgumentError, 'POA codes required (comma-separated)' if args[:poa_codes].blank?

    poa_codes = [args[:poa_codes], *args.extras].compact.uniq

    Rails.logger.tagged('rake:vso:disable_individual_acceptance') do
      Rails.logger.info("Received POA codes: #{poa_codes.join(', ')}")
      Rails.logger.info('Disabling individual acceptance for matching organization(s)...')

      result = AccreditedRepresentativePortal::DisableIndividualAcceptance2122Service.call(poa_codes:)

      Rails.logger.info(
        "Set acceptance_mode=any_request for #{result[:reps_updated]} " \
        'active rep-org relationship(s).'
      )
    end
  end
end
