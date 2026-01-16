# frozen_string_literal: true

require 'sidekiq'
require 'vets/shared_logging'
require 'meb_api/confirmation_email_config'
require 'meb_api/email_error_logger'

module MebApi
  module V0
    class BaseConfirmationEmailWorker
      include Sidekiq::Worker
      include Vets::SharedLogging
      sidekiq_options retry: 14

      STATS_KEY = 'api.meb.confirmation_email'

      sidekiq_retries_exhausted do |job, _ex|
        form_type = job['class'].constantize::FORM_TYPE
        form_tag = job['class'].constantize::FORM_TAG
        claim_status, email, _first_name, user_icn = job['args']

        Rails.logger.error(
          'MEB confirmation email retries exhausted',
          {
            form_type:,
            claim_status:,
            user_icn:,
            email_present: email.present?,
            sidekiq_jid: job['jid']
          }
        )

        normalized_status = MebApi::ConfirmationEmailConfig.normalize_claim_status(claim_status)
        StatsD.increment(
          "#{STATS_KEY}.retries_exhausted",
          tags: [form_tag, "claim_status:#{normalized_status}"]
        )
      end

      def perform(claim_status, email, first_name, user_icn)
        template_id = MebApi::ConfirmationEmailConfig.template_id(
          form_type: self.class::FORM_TYPE,
          claim_status:
        )

        log_worker_attempt(claim_status, template_id, email.present?)

        VANotify::EmailJob.perform_async(
          email,
          template_id,
          {
            'first_name' => first_name,
            'date_submitted' => Time.zone.today.strftime('%B %d, %Y')
          }
        )

        log_worker_success(claim_status, template_id)
      rescue => e
        log_worker_error(e, claim_status, template_id, email.present?, user_icn)
        raise # Re-raise to allow Sidekiq retry logic
      end

      private

      def log_worker_attempt(claim_status, template_id, email_present)
        Rails.logger.info(
          'MEB confirmation email enqueue attempt',
          {
            form_type: self.class::FORM_TYPE,
            claim_status:,
            template_id:,
            email_present:
          }
        )
      end

      def log_worker_success(claim_status, template_id)
        normalized_status = MebApi::ConfirmationEmailConfig.normalize_claim_status(claim_status)
        Rails.logger.info(
          'MEB confirmation email enqueued successfully',
          {
            form_type: self.class::FORM_TYPE,
            claim_status:,
            template_id:
          }
        )
        StatsD.increment("#{STATS_KEY}.enqueued",
                         tags: [self.class::FORM_TAG, "claim_status:#{normalized_status}"])
      end

      def log_worker_error(error, claim_status, template_id, email_present, user_icn)
        normalized_status = MebApi::ConfirmationEmailConfig.normalize_claim_status(claim_status)
        error_class = error.class.name

        error_logger = MebApi::EmailErrorLogger.new(
          error:,
          form_type: self.class::FORM_TYPE,
          form_tag: self.class::FORM_TAG
        )

        log_params = error_logger.log_params(
          claim_status:,
          template_id:,
          email_present:,
          user_icn:
        )

        Rails.logger.error('MEB confirmation email enqueue failed', log_params)
        increment_error_metric(error_class, normalized_status, template_id)
      end

      def increment_error_metric(error_class, normalized_status, template_id)
        StatsD.increment(
          "#{STATS_KEY}.error",
          tags: [
            "error_class:#{error_class}",
            self.class::FORM_TAG,
            "claim_status:#{normalized_status}",
            "template_id:#{template_id}"
          ]
        )
      end
    end
  end
end
