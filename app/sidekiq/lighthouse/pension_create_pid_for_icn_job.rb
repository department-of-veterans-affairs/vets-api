module Lighthouse
  class PensionCreatePidForIcnJob
    include Sidekiq::Job

    # retry for one day
    # exhausted attempts will be logged in intent_to_file_queue_exhaustions table
    sidekiq_options retry: 14, queue: 'low'
    sidekiq_retries_exhausted do |msg, error|
      veteran_icn = msg['args']
      user_account = UserAccount.find_by(icn: veteran_icn)

      track_proxy_add_exhaustion(user_account&.id, error)
    end

    def perform(form_type, form_start_date, veteran_icn)
      adder_service = MPIProxyPersonAdder.new(veteran_icn)
      if adder_service.add_person_proxy_by_icn
        Lighthouse::CreateIntentToFileJob.perform_async(form_type, form_start_date, veteran_icn)
      end
    end

    private

    STATSD_KEY_PREFIX = 'worker.lighthouse.pension_create_pid_for_icn'
    DEFAULT_LOGGER_MESSAGE = 'Add person proxy by icn'

    def track_proxy_add_exhaustion(user_account_uuid, error)
      StatsD.increment("#{STATSD_KEY_PREFIX}.exhausted")
        context = {
          error:,
          user_account_uuid:
        }
        Rails.logger.error("#{DEFAULT_LOGGER_MESSAGE} exhausted", context)
    end
  end
end