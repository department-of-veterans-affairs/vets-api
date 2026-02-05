# frozen_string_literal: true

require 'benefits_intake_service/service'

class Form526StatusPollingJob
  include Sidekiq::Job
  sidekiq_options retry: false

  STATS_KEY = 'api.benefits_intake.submission_status'
  MAX_BATCH_SIZE = 1000
  attr_reader :max_batch_size

  def initialize(max_batch_size: MAX_BATCH_SIZE)
    @max_batch_size = max_batch_size
    @total_handled = 0
  end

  def perform
    Rails.logger.info('Beginning Form 526 Intake Status polling')
    submissions.in_batches(of: max_batch_size) do |batch|
      batch_ids = batch.pluck(:backup_submitted_claim_id).flatten
      response = api_to_poll.get_bulk_status_of_uploads(batch_ids)
      handle_response(response)
    end
    Rails.logger.info('Form 526 Intake Status polling complete',
                      total_handled: @total_handled)
  rescue => e
    Rails.logger.error('Error processing 526 Intake Status batch',
                       class: self.class.name, message: e.message)
  end

  private

  def api_to_poll
    @api_to_poll ||= BenefitsIntakeService::Service.new
  end

  def submissions
    @submissions ||= Form526Submission.pending_backup
  end

  def handle_response(response)
    response.body['data']&.each do |submission|
      final_status = submission.dig('attributes', 'final_status')
      status = submission.dig('attributes', 'status')
      form_submission = Form526Submission.find_by(backup_submitted_claim_id: submission['id'])

      if final_status == true
        handle_submission(status, form_submission)
        @total_handled += 1
      else
        Rails.logger.info(
          'Final status not yet available from Benefits Intake API for 526 submission',
          status:, form_submission_id: form_submission&.id
        )
      end
    end
  end

  def handle_submission(status, form_submission)
    submission_id = form_submission.id

    if %w[error expired].include? status
      log_result('failure', submission_id)
      form_submission.rejected!
      notify_veteran(submission_id)
    elsif status == 'vbms'
      log_result('true_success', submission_id)
      form_submission.accepted!
    elsif status == 'success'
      log_result('paranoid_success', submission_id)
      form_submission.paranoid_success!
      # Send Received Email once Backup Path is successful!
      if Flipper.enabled?(:disability_526_send_received_email_from_backup_path)
        form_submission.send_received_email('Form526StatusPollingJob#handle_submission paranoid_success!')
      end
    else
      Rails.logger.info(
        'Unknown or incomplete status returned from Benefits Intake API for 526 submission',
        status:, submission_id:
      )
    end
  end

  def log_result(result, submission_id)
    StatsD.increment("#{STATS_KEY}.526.#{result}")
    StatsD.increment("#{STATS_KEY}.all_forms.#{result}")

    if result == 'failure'
      Rails.logger.warn('Form526StatusPollingJob submission failure',
                        { result:, submission_id: })
    end
  end

  def notify_veteran(submission_id)
    if Flipper.enabled?(:form526_send_backup_submission_polling_failure_email_notice)
      Form526SubmissionFailureEmailJob.perform_async(submission_id, Time.now.utc.to_s)
    end
  end
end
