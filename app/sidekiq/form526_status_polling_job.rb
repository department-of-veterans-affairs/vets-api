# frozen_string_literal: true

require 'benefits_intake_service/service'

class Form526StatusPollingJob
  include Sidekiq::Job

  extend Logging::ThirdPartyTransaction::MethodWrapper

  sidekiq_options retry: false

  STATS_KEY = 'api.benefits_intake.submission_status'
  MAX_BATCH_SIZE = 1000

  attr_reader :max_batch_size, :total_handled

  wrap_with_logging :perform, {
    additional_instance_logs: {
      total_handled: [:total_handled]
    }
  }


  def initialize(max_batch_size: MAX_BATCH_SIZE)
    @max_batch_size = max_batch_size
    @total_handled = 0
  end

  def perform
    pending_form_submissions.each_slice(max_batch_size) do |batch|
      batch_ids = batch.pluck(&:backup_submitted_claim_id)
      response = service.get_bulk_status_of_uploads batch_ids
      handle_response(response, batch)
    end
  rescue => e
    Rails.logger.error('Error processing Intake Status batch', class: self.class.name, message: e.message)
  end

  private

  def service
    @service ||= BenefitsIntakeService::Service.new
  end

  def pending_submissions
    @pending_submissions ||= Form526Submission
                               .where.not(backup_submitted_claim_id: nil)
                               .where(aasm_state: 'delivered_to_backup')
  end

  def handle_response(response)
    response.body['data']&.each do |submission|
      status = submission.dig('attributes', 'status')

      form_id = pending_submissions.find do |submission_from_db|
        submission_from_db.benefits_intake_uuid == submission['id']
      end.form_type

      if status == 'error' || status == 'expired'
        log_result('failure', form_id)
        handle_failure(submission)
      elsif status == 'vbms'
        log_result('success', form_id)
        handle_success(submission)
      else
        log_result('pending', form_id)
      end

      total_handled += 1
    end
  end

  def handle_failure(submission)
    form_submission = FormSubmission.find_by(benefits_intake_uuid: submission['id'])
    form_submission_attempt = form_submission
                              .form_submission_attempts
                              .where(aasm_state: 'pending')
                              .order(created_at: :asc)
                              .last
    form_submission_attempt.fail!
  end

  def handle_success(submission)
    form_submission = FormSubmission.find_by(benefits_intake_uuid: submission['id'])
    form_submission_attempt = form_submission
                              .form_submission_attempts
                              .where(aasm_state: 'pending')
                              .order(created_at: :asc)
                              .last
    form_submission_attempt.vbms!
  end

  def log_result(result, form_id)
    StatsD.increment("#{STATS_KEY}.526.#{result}")
    StatsD.increment("#{STATS_KEY}.all_forms.#{result}")
  end
end
