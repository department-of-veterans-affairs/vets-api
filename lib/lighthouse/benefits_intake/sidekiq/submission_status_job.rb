# frozen_string_literal: true

require 'burials/monitor'
require 'lighthouse/benefits_intake/service'
require 'pensions/monitor'
require 'pensions/notification_email'
require 'va_notify/notification_email/burial'
require 'pcpg/monitor'
require 'dependents/monitor'
require 'vre/monitor'

# Datadog Dashboard
# https://vagov.ddog-gov.com/dashboard/4d8-3fn-dbp/benefits-intake-form-submission-tracking
module BenefitsIntake
  class SubmissionStatusJob
    include Sidekiq::Job

    sidekiq_options retry: false

    STATS_KEY = 'api.benefits_intake.submission_status'
    STALE_SLA = Settings.lighthouse.benefits_intake.report.stale_sla || 10
    BATCH_SIZE = Settings.lighthouse.benefits_intake.report.batch_size || 1000

    # any status not listed will result in 'pending'
    STATUS_RESULT_MAP = {
      expired: 'failure', # Indicates that documents were not successfully uploaded within the 15-minute window.
      error: 'failure',   # Indicates that there was an error. Refer to the error code and detail for further information.
      vbms: 'success',    # Submission was successfully uploaded into a Veteran's eFolder within VBMS
      success: 'pending', # Submission was successfully received into Lighthouse systems
      pending: 'pending', # Submission is being processed
      stale: 'stale'      # Exceeds SLA (service level agreement) days for submission completion; non-lighthouse status
    }.freeze

    # A hash mapping form IDs to their corresponding handlers.
    # This constant is intentionally mutable.
    # @see register_handler
    FORM_HANDLERS = {} # rubocop:disable Style/MutableConstant

    ##
    # Registers a form class with a specific form ID.
    #
    # @param form_id [String] The form ID to register.
    # @param form_class [Class] The class associated with the form ID.
    #
    def self.register_handler(form_id, form_handler)
      FORM_HANDLERS[form_id] = form_handler
    end

    attr_reader :batch_size

    def initialize(batch_size: BATCH_SIZE)
      @batch_size = batch_size
    end

    def perform(form_id = nil)
      log(:info, 'started')

      pending_attempts = FormSubmissionAttempt.where(aasm_state: 'pending')

      # filter running this job to a specific form_id/form_type
      pending_attempts.select! { |pa| pa.form_type == form_id } if form_id

      batch_process(pending_attempts) unless pending_attempts.empty?

      log(:info, 'ended')
    end

    private

    attr_reader :batch_size, :form_id

    def log(level, msg, **payload)
      this = self.class.name
      Rails.logger.public_send(level, '%s: %s' % [this, msg.to_s], class: this, **payload)
    end

    def batch_process(pending_attempts)
      intake_service = BenefitsIntake::Service.new

      pending_attempts.each_slice(batch_size) do |batch|
        batch_uuids = batch.map(&:benefits_intake_uuid)
        log(:info, 'processing batch', batch_uuids:)

        response = intake_service.bulk_status(uuids: batch_uuids)

        log(:info, "bulk status response", response:)
        raise response.body unless response.success?

        next unless (data = response.body['data'])

        handle_response(data)
      end
    rescue => e
      log(:error, 'ERROR processing batch', message: e.message)
    end

    def pending_attempts_hash
      @pah ||= FormSubmissionAttempt.where(aasm_state: 'pending').index_by(&:benefits_intake_uuid)
    end

    # @see https://developer.va.gov/explore/api/benefits-intake/docs
    def handle_response(response_data)
      response_data.each { |submission|
        uuid = submission['id']

        next unless pending_attempts_hash[uuid]

        # Log the status for debugging
        status = submission.dig('attributes', 'status')
        log(:info, "Processing submission UUID: #{uuid}, Status: #{status}")

        update_attempt_record(uuid, status, submission)
        monitor_attempt_status(uuid, status)

        handle_attempt_result(uuid, status)
      }
    end

    def update_attempt_record(uuid, status, submission)
      form_submission_attempt = pending_attempts_hash[uuid]
      lighthouse_updated_at = submission.dig('attributes', 'updated_at')

      if status == 'expired'
        # Indicates that documents were not successfully uploaded within the 15-minute window.
        error_message = 'expired'
        form_submission_attempt.fail!

      elsif status == 'error'
        # Indicates that there was an error. Refer to the error code and detail for further information.
        error_message = "#{submission.dig('attributes', 'code')}: #{submission.dig('attributes', 'detail')}"
        form_submission_attempt.fail!

      elsif status == 'vbms'
        # Submission was successfully uploaded into a Veteran's eFolder within VBMS
        form_submission_attempt.vbms!

      form_submission_attempt.update(lighthouse_updated_at:, error_message:)
    end

    def monitor_attempt_status(uuid, status)
      form_submission_attempt, result = attempt_status_result(uuid, status)
      form_id = form_submission_attempt.form_submission.form_type

      metric = "#{STATS_KEY}.#{form_id}.#{result}"
      StatsD.increment(metric)
      StatsD.increment("#{STATS_KEY}.all_forms.#{result}")

      level = result == 'failure' ? :error : :info
      payload = {
        statsd: metric,
        form_id:,
        uuid:,
        result:,
        status:,
        time_to_transition: (Time.zone.now - form_submission_attempt.created_at).truncate,
        error_message: form_submission_attempt.error_message
      }
      log(level, "UUID: #{uuid}, status: #{status}, result: #{result}", **payload)
    end

    def handle_attempt_result(uuid, status)
      form_submission_attempt, result = attempt_status_result(uuid, status)
      form_id = form_submission_attempt.form_submission.form_type
      saved_claim_id = form_submission_attempt.form_submission.saved_claim_id

      FORM_HANDLERS[form_id]&.handle(result, saved_claim_id)
    end

    def attempt_status_result(uuid, status)
      form_submission_attempt = pending_attempts_hash[uuid]

      queue_time = (Time.zone.now - form_submission_attempt.created_at).truncate
      result = STATUS_RESULT_MAP[status.to_sym] || 'pending'
      result = 'stale' if (queue_time > STALE_SLA.days && result == 'pending')

      [form_submission_attempt, result]
    end

    # TODO: refactor - avoid require of module code, near duplication of process
    # rubocop:disable Metrics/MethodLength
    def monitor_failure(form_id, saved_claim_id, bi_uuid)
      context = {
        form_id: form_id,
        claim_id: saved_claim_id,
        benefits_intake_uuid: bi_uuid
      }
      call_location = caller_locations.first

      if %w[21P-530V2 21P-530].include?(form_id)
        claim = SavedClaim::Burial.find(saved_claim_id)
        if claim
          Burials::NotificationEmail.new(claim).deliver(:error)
          Burials::Monitor.new.log_silent_failure_avoided(context, nil, call_location:)
        else
          Burials::Monitor.new.log_silent_failure(context, nil, call_location:)
        end
      end

      if %w[21P-527EZ].include?(form_id)
        claim = Pensions::SavedClaim.find(saved_claim_id)
        if claim
          Pensions::NotificationEmail.new(claim).deliver(:error)
          Pensions::Monitor.new.log_silent_failure_avoided(context, nil, call_location:)
        else
          Pensions::Monitor.new.log_silent_failure(context, nil, call_location:)
        end
      end

      # Dependents
      if %w[686C-674].include?(form_id)
        claim = SavedClaim::DependencyClaim.find(saved_claim_id)
        if claim
          claim.send_failure_email
          Dependents::Monitor.new.log_silent_failure_avoided(context, nil, call_location:)
        else
          Dependents::Monitor.new.log_silent_failure(context, nil, call_location:)
        end
      end

      # PCPG
      if %w[28-8832].include?(form_id)
        claim = SavedClaim::EducationCareerCounselingClaim.find(saved_claim_id)
        if claim
          claim.send_failure_email
          PCPG::Monitor.new.log_silent_failure_avoided(context, nil, call_location:)
        else
          PCPG::Monitor.new.log_silent_failure(ocntext, nil, call_location:)
        end
      end

      # VRE
      if %w[28-1900].include?(form_id)
        claim = SavedClaim::VeteranReadinessEmploymentClaim.find(saved_claim_id)
        if claim
          claim.send_failure_email
          VRE::Monitor.new.log_silent_failure_avoided(context, nil, call_location:)
        else
          VRE::Monitor.new.log_silent_failure(context, nil, call_location:)
        end
      end
    end
    # rubocop:enable Metrics/MethodLength


    # end class SubmissionStatusJob
  end

  # end module BenefitsIntake
end

