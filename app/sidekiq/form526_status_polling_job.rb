# frozen_string_literal: true

require 'benefits_intake_service/service'

class Form526StatusPollingJob
  include Sidekiq::Job
  sidekiq_options retry: false

  STATS_KEY = 'api.benefits_intake.submission_status'
  MAX_BATCH_SIZE = 1000
  attr_reader :max_batch_size, :paranoid

  def initialize(max_batch_size: MAX_BATCH_SIZE, paranoid: false)
    @max_batch_size = max_batch_size
    @total_handled = 0
    @paranoid = paranoid
  end

  def perform
    Rails.logger.info('Beginning Form 526 Intake Status polling', paranoid:)
    submissions.in_batches(of: max_batch_size) do |batch|
      batch_ids = batch.pluck(:backup_submitted_claim_id).flatten
      response = api_to_poll.get_bulk_status_of_uploads(batch_ids)
      handle_response(response)
    end
    Rails.logger.info('Form 526 Intake Status polling complete',
                      total_handled: @total_handled, paranoid:)
  rescue => e
    Rails.logger.error('Error processing 526 Intake Status batch',
                       class: self.class.name, message: e.message, paranoid:)
  end

  private

  def api_to_poll
    @api_to_poll ||= BenefitsIntakeService::Service.new
  end

  def submissions
    @submissions ||= if paranoid
                       Form526Submission.paranoid_success_type
                     else
                       Form526Submission.pending_backup
                     end
  end

  def handle_response(response)
    response.body['data']&.each do |submission|
      status = submission.dig('attributes', 'status')
      form_submission = Form526Submission.find_by(backup_submitted_claim_id: submission['id'])

      handle_submission(status, form_submission)
      @total_handled += 1
    end
  end

  def handle_submission(status, form_submission)
    if %w[error expired].include? status
      log_result('failure')
      form_submission.rejected!
    elsif status == 'vbms'
      log_result('true success')
      form_submission.accepted!
    elsif status == 'success' && !paranoid
      # This is a weird, condition, here's how it works:
      # if paranoid: true, then this job is only checking submissions already paranoid_success_type
      # if paranoid: false, then this job is only checking submissions that are pending
      # THEREFORE
      # if paranoid: true, setting paranoid_success_type would be redundant
      # if paranoid: false, this submission is pending but needs to become paranoid success
      log_result('paranoid success')
      form_submission.paranoid_success!
    elsif status == 'processing' && paranoid
      log_result('reverted to processing')
      form_submission.update!(backup_submitted_claim_status: nil)
    else
      Rails.logger.info(
        'Unknown or incomplete status returned from Benefits Intake API for 526 submission',
        status:,
        submission_id: form_submission.id
      )
    end
  end

  def log_result(result)
    StatsD.increment("#{STATS_KEY}.526.#{result}")
    StatsD.increment("#{STATS_KEY}.all_forms.#{result}")
  end
end
