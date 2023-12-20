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
    stats = handle_response(response)
    Rails.logger.info({ message: 'BenefitsIntakeStatusJob ended' }.merge(stats))
  end

  private

  def handle_response(response)
    total_submissions_handled = 0
    pending_submissions_handled = 0
    failed_submissions_handled = 0
    successful_submissions_handled = 0
    response.body['data'].each do |submission|
      if submission.dig('attributes', 'status') == 'error' || submission.dig('attributes', 'status') == 'expired'
        failed_submissions_handled += 1
        handle_failure(submission)
      elsif submission.dig('attributes', 'status') == 'vbms'
        successful_submissions_handled += 1
        handle_success(submission)
      else
        pending_submissions_handled += 1
      end
      total_submissions_handled += 1
    end
    {
      total_submissions_handled:, pending_submissions_handled:,
      failed_submissions_handled:, successful_submissions_handled:
    }
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
