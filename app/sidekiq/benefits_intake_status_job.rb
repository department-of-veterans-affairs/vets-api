# frozen_string_literal: true

require 'benefits_intake_service/service'

class BenefitsIntakeStatusJob
  include Sidekiq::Job
  STATS_KEY = 'api.benefits_intake.submission_status'

  def perform
    Rails.logger.info('BenefitsIntakeStatusJob started')
    pending_form_submissions = FormSubmission
                               .joins(:form_submission_attempts)
                               .where(form_submission_attempts: { aasm_state: 'pending' })
    pending_form_submission_ids = pending_form_submissions.map(&:benefits_intake_uuid)
    response = BenefitsIntakeService::Service.new.get_bulk_status_of_uploads(pending_form_submission_ids)
    total_handled = handle_response(response, pending_form_submissions)
    Rails.logger.info('BenefitsIntakeStatusJob ended', total_handled:)
  end

  private

  def handle_response(response, pending_form_submissions)
    total_handled = 0

    response.body['data']&.each do |submission|
      form_id = pending_form_submissions.find do |submission_from_db|
        submission_from_db.benefits_intake_uuid == submission['id']
      end.form_type

      if submission.dig('attributes', 'status') == 'error' || submission.dig('attributes', 'status') == 'expired'
        log_result('failure', form_id)
        handle_failure(submission)
      elsif submission.dig('attributes', 'status') == 'vbms'
        log_result('success', form_id)
        handle_success(submission)
      else
        log_result('pending', form_id)
      end

      total_handled += 1
    end

    total_handled
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
    StatsD.increment("#{STATS_KEY}.#{form_id}.#{result}")
    StatsD.increment("#{STATS_KEY}.all_forms.#{result}")
    Rails.logger.info('BenefitsIntakeStatusJob', result:, form_id:)
  end
end
