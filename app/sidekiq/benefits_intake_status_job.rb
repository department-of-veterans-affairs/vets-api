# frozen_string_literal: true

require 'burials/monitor'
require 'lighthouse/benefits_intake/service'
require 'pensions/monitor'
require 'pensions/notification_email'
require 'burials/notification_email'
require 'pcpg/monitor'
require 'dependents/monitor'
require 'vre/monitor'

# Datadog Dashboard:
# https://vagov.ddog-gov.com/dashboard/4d8-3fn-dbp/benefits-intake-form-submission-tracking?fromUser=false&refresh_mode=sliding&view=spans&from_ts=1717772535566&to_ts=1718377335566&live=true
class BenefitsIntakeStatusJob
  include Sidekiq::Job

  sidekiq_options retry: false

  STATS_KEY = 'api.benefits_intake.submission_status'
  STALE_SLA = Settings.lighthouse.benefits_intake.report.stale_sla || 10
  BATCH_SIZE = Settings.lighthouse.benefits_intake.report.batch_size || 1000

  attr_reader :batch_size

  def initialize(batch_size: BATCH_SIZE)
    @batch_size = batch_size
  end

  def perform
    Rails.logger.info('BenefitsIntakeStatusJob started')
    pending_form_submission_attempts = FormSubmissionAttempt.where(aasm_state: 'pending')
    total_handled, result = batch_process(pending_form_submission_attempts)
    Rails.logger.info('BenefitsIntakeStatusJob ended', total_handled:) if result
  end

  private

  def batch_process(pending_form_submission_attempts)
    total_handled = 0
    intake_service = BenefitsIntake::Service.new

    pending_form_submission_attempts.each_slice(batch_size) do |batch|
      batch_uuids = batch.map(&:benefits_intake_uuid)
      response = intake_service.bulk_status(uuids: batch_uuids)

      # Log the entire response for debugging purposes
      Rails.logger.info("Received bulk status response: #{response.body}")

      raise response.body unless response.success?

      total_handled += handle_response(response)
    end

    [total_handled, true]
  rescue => e
    Rails.logger.error('Error processing Intake Status batch', class: self.class.name, message: e.message)
    [total_handled, false]
  end

  # rubocop:disable Metrics/MethodLength
  def handle_response(response)
    total_handled = 0

    # Ensure response body contains data, and log the data for debugging
    if response.body['data'].blank?
      Rails.logger.error("Response data is blank or missing: #{response.body}")
      return total_handled
    end

    response.body['data']&.each do |submission|
      uuid = submission['id']
      form_submission_attempt = form_submission_attempts_hash[uuid]
      form_submission = form_submission_attempt&.form_submission
      form_id = form_submission&.form_type
      saved_claim_id = form_submission&.saved_claim_id
      time_to_transition = (Time.zone.now - form_submission_attempt.created_at).truncate

      # https://developer.va.gov/explore/api/benefits-intake/docs
      status = submission.dig('attributes', 'status')

      # Log the status for debugging
      Rails.logger.info("Processing submission UUID: #{uuid}, Status: #{status}")

      lighthouse_updated_at = submission.dig('attributes', 'updated_at')
      if status == 'expired'
        # Expired - Indicate that documents were not successfully uploaded within the 15-minute window.
        error_message = 'expired'
        form_submission_attempt.update(error_message:, lighthouse_updated_at:)
        form_submission_attempt.fail!
        log_result('failure', form_id, uuid, time_to_transition, error_message)
        monitor_failure(form_id, saved_claim_id, uuid)
      elsif status == 'error'
        # Error - Indicates that there was an error. Refer to the error code and detail for further information.
        error_message = "#{submission.dig('attributes', 'code')}: #{submission.dig('attributes', 'detail')}"
        form_submission_attempt.update(error_message:, lighthouse_updated_at:)
        form_submission_attempt.fail!
        log_result('failure', form_id, uuid, time_to_transition, error_message)
        monitor_failure(form_id, saved_claim_id, uuid)
      elsif status == 'vbms'
        # submission was successfully uploaded into a Veteran's eFolder within VBMS
        form_submission_attempt.update(lighthouse_updated_at:)
        form_submission_attempt.vbms!
        log_result('success', form_id, uuid, time_to_transition)
        monitor_success(form_id, saved_claim_id, uuid)
      elsif time_to_transition > STALE_SLA.days
        # exceeds SLA (service level agreement) days for submission completion
        log_result('stale', form_id, uuid, time_to_transition)
      else
        # no change being tracked
        log_result('pending', form_id, uuid)
        Rails.logger.info(
          "Submission UUID: #{uuid} is still pending, status: #{status}, time to transition: #{time_to_transition}"
        )
      end

      total_handled += 1
    end

    total_handled
  end
  # rubocop:enable Metrics/MethodLength

  def log_result(result, form_id, uuid, time_to_transition = nil, error_message = nil)
    StatsD.increment("#{STATS_KEY}.#{form_id}.#{result}")
    StatsD.increment("#{STATS_KEY}.all_forms.#{result}")
    if result == 'failure'
      Rails.logger.error('BenefitsIntakeStatusJob', result:, form_id:, uuid:, time_to_transition:, error_message:)
    else
      Rails.logger.info('BenefitsIntakeStatusJob', result:, form_id:, uuid:, time_to_transition:)
    end
  end

  def monitor_success(form_id, saved_claim_id, bi_uuid)
    # Remove this logic after SubmissionStatusJob replaces this one
    claim = SavedClaim.find_by(id: saved_claim_id)
    context = {
      form_id: form_id,
      claim_id: saved_claim_id,
      benefits_intake_uuid: bi_uuid
    }

    if form_id == '21P-530EZ' && Flipper.enabled?(:burial_received_email_notification)
      unless claim
        Burials::Monitor.new.log_silent_failure(context, nil, call_location: caller_locations.first)
        return
      end

      Burials::NotificationEmail.new(claim.id).deliver(:received)
    end
    if %w[21P-527EZ].include?(form_id) && Flipper.enabled?(:pension_received_email_notification)
      unless claim
        Pensions::Monitor.new.log_silent_failure(context, nil, call_location: caller_locations.first)
        return
      end

      Pensions::NotificationEmail.new(saved_claim_id).deliver(:received)
    end
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

    if %w[21P-530EZ 21P-530V2].include?(form_id)
      claim = SavedClaim::Burial.find(saved_claim_id)
      if claim
        Burials::NotificationEmail.new(claim.id).deliver(:error)
        Burials::Monitor.new.log_silent_failure_avoided(context, nil, call_location:)
      else
        Burials::Monitor.new.log_silent_failure(context, nil, call_location:)
      end
    end

    if %w[21P-527EZ].include?(form_id)
      claim = Pensions::SavedClaim.find(saved_claim_id)
      if claim
        Pensions::NotificationEmail.new(claim.id).deliver(:error)
        Pensions::Monitor.new.log_silent_failure_avoided(context, nil, call_location:)
      else
        Pensions::Monitor.new.log_silent_failure(context, nil, call_location:)
      end
    end

    # Dependents
    if %w[686C-674].include?(form_id)
      claim = SavedClaim::DependencyClaim.find(saved_claim_id)
      email = if claim.present?
                claim.parsed_form.dig('dependents_application', 'veteran_contact_information', 'email_address')
              end
      if claim.present? && email.present?
        claim.send_failure_email(email)
        Dependents::Monitor.new.log_silent_failure_avoided(context, nil, call_location:)
      else
        Dependents::Monitor.new.log_silent_failure(context, nil, call_location:)
      end
    end

    # PCPG
    if %w[28-8832].include?(form_id)
      claim = SavedClaim::EducationCareerCounselingClaim.find(saved_claim_id)
      email = claim.parsed_form.dig('claimantInformation', 'emailAddress') if claim.present?
      if claim.present? && email.present?
        claim.send_failure_email(email)
        PCPG::Monitor.new.log_silent_failure_avoided(context, nil, call_location:)
      else
        PCPG::Monitor.new.log_silent_failure(ocntext, nil, call_location:)
      end
    end

    # VRE
    if %w[28-1900].include?(form_id)
      claim = SavedClaim::VeteranReadinessEmploymentClaim.find(saved_claim_id)
      email = claim.parsed_form['email'] if claim.present?
      if claim.present? && email.present?
        claim.send_failure_email(email)
        VRE::Monitor.new.log_silent_failure_avoided(context, nil, call_location:)
      else
        VRE::Monitor.new.log_silent_failure(context, nil, call_location:)
      end
    end
  end
  # rubocop:enable Metrics/MethodLength

  def form_submission_attempts_hash
    @_form_submission_attempts_hash ||= FormSubmissionAttempt
                                        .where(aasm_state: 'pending')
                                        .index_by(&:benefits_intake_uuid)
  end
end
