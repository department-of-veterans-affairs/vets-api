# frozen_string_literal: true

require 'benefits_intake_service/service'

class BenefitsIntakeStatusJob
  include Sidekiq::Job
  STATS_KEY = 'api.benefits_intake.submission_status'

  def perform
    Rails.logger.info('BenefitsIntakeStatusJob started')
    pending_form_submission_ids = FormSubmission
                                  .joins(:form_submission_attempts)
                                  .where(form_submission_attempts: { aasm_state: 'pending' })
                                  .map(&:benefits_intake_uuid)
    response = BenefitsIntakeService::Service.new.get_bulk_status_of_uploads(pending_form_submission_ids)
    handle_response(response)
    Rails.logger.info('BenefitsIntakeStatusJob ended')
  end

  private

  def handle_response(response)
    response.body['data']&.each do |submission|
      if submission.dig('attributes', 'status') == 'error' || submission.dig('attributes', 'status') == 'expired'
        StatsD.increment("#{STATS_KEY}.failure")
        handle_failure(submission)
      elsif submission.dig('attributes', 'status') == 'vbms'
        StatsD.increment("#{STATS_KEY}.success")
        handle_success(submission)
      else
        StatsD.increment("#{STATS_KEY}.pending")
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
