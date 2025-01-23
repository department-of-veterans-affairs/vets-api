# frozen_string_literal: true

require 'benefits_intake_service/service'

class Form526ParanoidSuccessPollingJob
  include Sidekiq::Job
  sidekiq_options retry: false

  MAX_BATCH_SIZE = 1000
  attr_reader :max_batch_size, :change_totals, :total_checked

  def initialize(max_batch_size: MAX_BATCH_SIZE)
    @max_batch_size = max_batch_size
    @total_checked = 0
    @change_totals = {}
  end

  def perform
    Rails.logger.info('Beginning Form 526 paranoid_success polling')
    submissions.in_batches(of: max_batch_size) do |batch|
      batch_ids = batch.pluck(:backup_submitted_claim_id).flatten
      response = api_to_poll.get_bulk_status_of_uploads(batch_ids)
      handle_response(response)
    end
    Rails.logger.info('Form 526 paranoid_success polling complete',
                      total_checked:, change_totals:)
  rescue => e
    Rails.logger.error('Error processing 526 paranoid_success batch',
                       class: self.class.name, message: e.message)
  end

  private

  def api_to_poll
    @api_to_poll ||= BenefitsIntakeService::Service.new
  end

  def submissions
    @submissions ||= Form526Submission.paranoid_success_type
  end

  def handle_response(response)
    response.body['data']&.each do |submission|
      status = submission.dig('attributes', 'status')
      id = submission['id']
      form_submission = Form526Submission.find_by(backup_submitted_claim_id: id)
      handle_submission(form_submission, status, id)
      @total_checked += 1
    end
  end

  def handle_submission(form_submission, status, id)
    if %w[error expired].include?(status)
      form_submission.rejected!
      log_result('failed', id)
    elsif status == 'vbms'
      form_submission.accepted!
      log_result('marked as true success', id)
    elsif status == 'processing'
      form_submission.update!(backup_submitted_claim_status: nil)
      log_result('reverted to processing', id)
    elsif status != 'success'
      Rails.logger.error('Paranoid Success transitioned to unknown status',
                         status:, submission_id: id)
      form_submission.rejected!
    end
    count_change(status) unless status == 'success'
  end

  def count_change(status)
    change_totals[status] ||= 0
    change_totals[status] += 1
  end

  def log_result(change, submission_id)
    Rails.logger.info('Paranoid Success submission changed', submission_id:, change:)
  end
end
