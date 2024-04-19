# frozen_string_literal: true

require 'benefits_intake_service/service'

class BenefitsIntakeStatusJob
  include Sidekiq::Job

  sidekiq_options retry: false

  STATS_KEY = 'api.benefits_intake.submission_status'
  MAX_BATCH_SIZE = 1000

  attr_reader :max_batch_size

  def initialize(max_batch_size: MAX_BATCH_SIZE)
    @max_batch_size = max_batch_size
  end

  def perform
    Rails.logger.info('BenefitsIntakeStatusJob started')
    pending_form_submissions = FormSubmission
                               .joins(:form_submission_attempts)
                               .where(form_submission_attempts: { aasm_state: 'pending' })
    total_handled, result = batch_process(pending_form_submissions)
    Rails.logger.info('BenefitsIntakeStatusJob ended', total_handled:) if result
  end

  private

  def handle_response(response, pending_form_submissions)
    total_handled = 0

    response.body['data']&.each do |submission|
      form_id = pending_form_submissions.find do |submission_from_db|
        submission_from_db.benefits_intake_uuid == submission['id']
      end.form_type

      if submission.dig('attributes', 'status') == 'error' || submission.dig('attributes', 'status') == 'expired'
        form_submission_attempt = handle_failure(submission)
        time_to_transition = (Time.now - form_submission_attempt.created_at).truncate
        log_result('failure', form_id, time_to_transition)
      elsif submission.dig('attributes', 'status') == 'vbms'
        form_submission_attempt = handle_success(submission)
        time_to_transition = (Time.now - form_submission_attempt.created_at).truncate
        log_result('success', form_id, time_to_transition)
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
    form_submission_attempt
  end

  def handle_success(submission)
    form_submission = FormSubmission.find_by(benefits_intake_uuid: submission['id'])
    form_submission_attempt = form_submission
                              .form_submission_attempts
                              .where(aasm_state: 'pending')
                              .order(created_at: :asc)
                              .last
    form_submission_attempt.vbms!
    form_submission_attempt
  end

  def batch_process(pending_form_submissions)
    total_handled = 0

    pending_form_submissions.each_slice(max_batch_size) do |batch|
      batch_ids = batch.map(&:benefits_intake_uuid)
      response = BenefitsIntakeService::Service.new.get_bulk_status_of_uploads(batch_ids)
      total_handled += handle_response(response, batch)
    end

    [total_handled, true]
  rescue => e
    Rails.logger.error('Error processing Intake Status batch', class: self.class.name, message: e.message)
    [total_handled, false]
  end

  def log_result(result, form_id, time_to_transition = nil)
    StatsD.increment("#{STATS_KEY}.#{form_id}.#{result}")
    StatsD.increment("#{STATS_KEY}.all_forms.#{result}")
    Rails.logger.info('BenefitsIntakeStatusJob', result:, form_id:, time_to_transition:)
  end
end
