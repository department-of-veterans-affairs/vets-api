# frozen_string_literal: true

require 'logging/third_party_transaction'

module BGS
  class FlashUpdater
    include Sidekiq::Job
    include SentryLogging

    extend Logging::ThirdPartyTransaction::MethodWrapper

    attr_accessor :submission_id

    # Sidekiq has built in exponential back-off functionality for retries
    # A max retry attempt of 10 will result in a run time of ~8 hours
    # This job is invoked from 526 background job
    sidekiq_options retry: 10
    STATSD_KEY_PREFIX = 'worker.bgs.flash_updater'

    wrap_with_logging(
      :add_flashes,
      additional_class_logs: {
        action: 'Begin Flash addition job'
      },
      additional_instance_logs: {
        submission_id: %i[submission_id]
      }
    )

    sidekiq_retries_exhausted do |msg, _ex|
      job_id = msg['jid']
      error_class = msg['error_class']
      error_message = msg['error_message']
      timestamp = Time.now.utc
      form526_submission_id = msg['args'].first

      form_job_status = Form526JobStatus.find_by(job_id:)
      bgjob_errors = form_job_status.bgjob_errors || {}
      new_error = {
        "#{timestamp.to_i}": {
          caller_method: __method__.to_s,
          error_class:,
          error_message:,
          timestamp:,
          form526_submission_id:
        }
      }
      form_job_status.update(
        status: Form526JobStatus::STATUS[:exhausted],
        bgjob_errors: bgjob_errors.merge(new_error)
      )

      StatsD.increment("#{STATSD_KEY_PREFIX}.exhausted")

      ::Rails.logger.warn(
        'Flash Updater Retries exhausted',
        { job_id:, error_class:, error_message:, timestamp:, form526_submission_id: }
      )
    rescue => e
      ::Rails.logger.error(
        'Failure in FlashUpdater#sidekiq_retries_exhausted',
        {
          messaged_content: e.message,
          job_id:,
          submission_id: form526_submission_id,
          pre_exhaustion_failure: {
            error_class:,
            error_message:
          }
        }
      )
      raise e
    end

    def perform(submission_id)
      @submission_id = submission_id

      add_flashes
      confirm_flash_addition
    end

    private

    def add_flashes
      flashes.each do |flash_name|
        # NOTE: Assumption that duplicate flashes are ignored when submitted
        service.add_flash(file_number: ssn, flash_name:)
      rescue BGS::ShareError, BGS::PublicError => e
        Sentry.set_tags(source: '526EZ-all-claims', submission_id:)
        log_exception_to_sentry(e)
      end
    end

    def confirm_flash_addition
      assigned_flashes = service.find_assigned_flashes(ssn)[:flashes]
      flashes.each do |flash_name|
        assigned_flash = assigned_flashes.find { |af| af[:flash_name].strip == flash_name }
        if assigned_flash.blank?
          Sentry.set_tags(source: '526EZ-all-claims', submission_id:)
          e = StandardError.new("Failed to assign '#{flash_name}' to Veteran")
          log_exception_to_sentry(e)
        end
      end
    end

    def flashes
      @flashes ||= submission.form[Form526Submission::FLASHES]
    end

    def submission
      @submission ||= Form526Submission.find(submission_id)
    end

    def ssn
      @ssn ||= submission.auth_headers['va_eauth_pnid']
    end

    def service
      @service ||= bgs_service.claimant
    end

    def bgs_service
      # BGS::Services is in the BGS bgs-ext gem, not to be confused with BGS::Service
      BGS::Services.new(
        external_uid: ssn,
        external_key: ssn
      )
    end
  end
end
