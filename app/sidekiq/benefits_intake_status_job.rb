# frozen_string_literal: true

class BenefitsIntakeStatusJob
  include Sidekiq::Job

  def perform
    pending_form_submission_ids = FormSubmission
                                  .joins(:form_submission_attempts)
                                  .where('form_submission_attempt.aasm_state = pending')
                                  .map(&:benefits_intake_uuid)
    response = BenefitsIntakeService::Service.get_bulk_status_of_uploads(pending_form_submission_ids)
    handle_response(response) if response.status == 200
  end

  private

  def handle_response(response)
    parsed_response = JSON.parse(response.body['data'])
    parsed_response.each do |submission|
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
    form_submission_attempt.fail
  end

  def handle_success(submission)
    form_submission = FormSubmission.find_by(benefits_intake_uuid: submission['id'])
    form_submission_attempt = form_submission
                              .form_submission_attempts
                              .where(aasm_state: 'pending')
                              .order(created_at: :asc)
                              .last
    form_submission_attempt.succeed
  end
end
