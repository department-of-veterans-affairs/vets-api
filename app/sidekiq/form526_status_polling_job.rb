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
    Rails.logger.info('Beginning Form 526 Intake Status polling', total_submissions: submissions.count)
    submissions.each_slice(max_batch_size) do |batch|
      batch_ids = batch.pluck(:backup_submitted_claim_id).flatten
      response = api_to_poll.get_bulk_status_of_uploads(batch_ids)
      handle_response(response)
    end
    Rails.logger.info('Form 526 Intake Status polling complete', total_handled: @total_handled)
  rescue => e
    Rails.logger.error('Error processing 526 Intake Status batch', class: self.class.name, message: e.message)
  end

  private

  def api_to_poll
    @api_to_poll ||= BenefitsIntakeService::Service.new
  end

  def submissions
    @submissions ||= Form526Submission.pending_backup_submissions
  end

  def handle_response(response)
    response.body['data']&.each do |submission|
      status = submission.dig('attributes', 'status')
      submission_guid = submission['id']

      if %w[error expired].include? status
        log_result('failure')
        handle_failure(submission_guid)
      elsif %w[vbms success].include? status
        log_result('success')
        handle_success(submission_guid)
      else
        Rails.logger.warn(
          'Unknown status returned from Benefits Intake API for 526 submission',
          status:,
          submission_id: submission.id
        )
      end
      @total_handled += 1
    end
  end

  def handle_failure(submission_guid)
    form_submission = submissions.find_by(backup_submitted_claim_id: submission_guid)
    form_submission.reject_from_backup!
  end

  def handle_success(submission_guid)
    form_submission = submissions.find_by(backup_submitted_claim_id: submission_guid)
    form_submission.finalize_success!
  end

  def log_result(result)
    StatsD.increment("#{STATS_KEY}.526.#{result}")
    StatsD.increment("#{STATS_KEY}.all_forms.#{result}")
  end
end
