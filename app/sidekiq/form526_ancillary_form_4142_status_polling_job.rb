# frozen_string_literal: true

require 'benefits_intake_service/service'

class Form526AncillaryForm4142StatusPollingJob < BenefitsIntakeStatusPollingJob
  def initialize(max_batch_size: MAX_BATCH_SIZE)
    @max_batch_size = max_batch_size
    @total_handled = 0
  end

  def perform
    Rails.logger.info('Beginning Form 526 Intake Status polling')
    submissions.in_batches(of: max_batch_size) do |batch|
      batch_ids = batch.pluck(:benefits_intake_uuid).flatten
      response = api_to_poll.get_bulk_status_of_uploads(batch_ids)
      handle_response(response)
    end
    Rails.logger.info('Form 526 Intake Status polling complete',
                      total_handled: @total_handled)
  rescue => e
    Rails.logger.error('Error processing 526 Intake Status batch',
                       class: self.class.name, message: e.message)
  end

  def self.pending
    Form4142StatusPollingRecord.pending
  end

  def self.pending_ids
    pending.pluck(:benefits_intake_uuid)
  end

  private

  def submissions
    Form4142StatusPollingRecord.pending
  end

  def handle_response(response)
    response.body['data']&.each do |submission|
      status = submission.dig('attributes', 'status')
      polling_record = Form4142StatusPollingRecord.find_by(benefits_intake_uuid: submission['id'])
      handle_submission(status, polling_record, status)
      @total_handled += 1
    end
  end

  def handle_submission(status, polling_record, original_status)
    if %w[error expired].include? status
      polling_record.status = :errored
      polling_record.save!
      log_result('errored', polling_record, original_status)
    elsif status == 'vbms'
      polling_record.status = :success
      polling_record.save!
      log_result('success', polling_record, original_status)
    else
      Rails.logger.info(
        'Unknown or incomplete status returned from Benefits Intake API for 526 submission',
        status:,
        previous_status: original_status,
        submission_id: polling_record.submission_id,
        lighthouse_submission: {
          id: polling_record.benefits_intake_uuid
        }
      )
    end
  end

  def log_details(result, polling_record, original_status)
    info = {
      form_id: Form526Submission::FORM_4142,
      parent_form_id: Form526Submission::FORM_526,
      message: 'Form526 Submission, Form4142 polled status result',
      result:,
      previous_status: original_status,
      submission_id: polling_record.submission_id,
      lighthouse_submission: {
        id: polling_record.benefits_intake_uuid
      }
    }
    ::Rails.logger.info(info)
  end

  def log_result(result, polling_record, original_status)
    StatsD.increment("#{STATS_KEY}.4142.#{result}")
    log_details(result, polling_record, original_status)
  end
end
