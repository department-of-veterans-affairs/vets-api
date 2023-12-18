# frozen_string_literal: true

require 'benefits_intake_service/service'

class BenefitsIntakeStatusJob
  include Sidekiq::Job

  def perform
    Rails.logger.info('BenefitsIntakeStatusJob started')
    pending_form_submission_ids = FormSubmission
                                  .joins(:form_submission_attempts)
                                  .where(form_submission_attempts: { aasm_state: 'pending' })
                                  .map(&:benefits_intake_uuid)
    response = BenefitsIntakeService::Service.new.get_bulk_status_of_uploads(pending_form_submission_ids)
    handle_response(response)
    submissions_handled = response.body['data'].count
    cumulative_failures = FormSubmissionAttempt.where(aasm_state: 'failure').count
    cumulative_vbms = FormSubmissionAttempt.where(aasm_state: 'vbms').count
    cumulative_pending = FormSubmissionAttempt.where(aasm_state: 'pending').count
    Rails.logger.info({
      message: 'BenefitsIntakeStatusJob ended',
      submissions_handled:,
    })
    Rails.logger.info({
      message: 'Cumulative BenefitsIntakeStatusJob stats',
      cumulative_failures:,
      cumulative_vbms:,
      cumulative_pending:
    })
  end

  private

  def handle_response(response)
    response.body['data'].each do |submission|
      if submission.dig('attributes', 'status') == 'error' || submission.dig('attributes', 'status') == 'expired'
        handle_failure(submission)
      elsif submission.dig('attributes', 'status') == 'vbms'
        handle_success(submission)
      end
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
end
