# frozen_string_literal: true

require 'lighthouse/benefits_claims/person_proxy_add/monitor'

module Lighthouse
  # proxy job to perform pid creation before intent-to-file
  class PensionCreatePidForIcnJob
    include Sidekiq::Job

    # retry for one day
    # exhausted attempts will be logged in datadog and rails logger
    sidekiq_options retry: 14, queue: 'low'
    sidekiq_retries_exhausted do |msg, error|
      form_type, form_start_date, veteran_icn = msg['args']
      user_account = UserAccount.find_by(icn: veteran_icn)
      monitor = BenefitsClaims::PersonProxyAdd::Monitor.new

      monitor.track_proxy_add_exhaustion(form_type, form_start_date, user_account&.id, error)
    end

    # attempt to add/retrieve a pid, then call intnet-to-file job
    # @see Lighthouse::CreateIntentToFileJob
    #
    # @param form_type [String] the form_id, form_type; eg. '21P-527EZ'
    # @param form_start_date [DateTime] date to set ITF
    # @param veteran_icn
    #
    def perform(form_type, form_start_date, veteran_icn)
      adder_service = MPIProxyPersonAdder.new(veteran_icn)
      if adder_service.add_person_proxy_by_icn
        Lighthouse::CreateIntentToFileJob.perform_async(form_type, form_start_date, veteran_icn)
      end
    rescue ArgumentError, MPI::Errors::RecordNotFound => e
      context = { error: e }
      Rails.logger.error(
        'PensionCreatePidForIcnJob caught exception not meant for retry. ITF auto creation cancelled.', context
      )
    end
  end
end
