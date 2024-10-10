# frozen_string_literal: true

require 'benefits_intake_service/service'

class Form526AncillaryForm4142StatusPollingJob < BenefitsIntakeStatusPollingJob
  POLLING_FLIPPER_KEY = :disability_526_form4142_polling_records
  EMAIL_FLIPPER_KEY = :disability_526_form4142_polling_record_failure_email
  OVERAL_4142_MAILER_KEY = :form526_send_4142_failure_notification

  def perform
    unless Flipper.enabled?(POLLING_FLIPPER_KEY)
      msg = "#{class_name} disabled via flipper :#{POLLING_FLIPPER_KEY}"
      Rails.logger.info(msg)
      return true
    end
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

  def send_failure_email!(status, polling_record, original_status)
    if Flipper.enabled?(OVERALL_4142_MAILER_KEY) && Flipper.enabled?(EMAIL_FLIPPER_KEY)
      EVSS::DisabilityCompensationForm::Form4142DocumentUploadFailureEmail.perform_async(polling_record.submission_id)
    else
      message = "#{class_name} email disabled via flipper :#{EMAIL_FLIPPER_KEY} or :#{OVERALL_4142_MAILER_KEY}"
      log_hash = log_detail_hash(status:, polling_record:, original_status:, message:)
      Rails.logger.info(log_hash)
    end
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
      send_failure_email!(status, polling_record, original_status)
    elsif status == 'vbms'
      polling_record.status = :success
      polling_record.save!
      log_result('success', polling_record, original_status)
    else
      Rails.logger.info(
        log_detail_hash(message: 'Unknown or incomplete status returned from Benefits Intake API for 526 submission',
                        status:,
                        polling_record:,
                        original_status:)
      )
    end
  end

  def log_detail_hash(result:, polling_record:, original_status:, message:)
    {
      form_id: Form526Submission::FORM_4142,
      parent_form_id: Form526Submission::FORM_526,
      message:,
      result:,
      previous_status: original_status,
      submission_id: polling_record.submission_id,
      lighthouse_submission: {
        id: polling_record.benefits_intake_uuid
      }
    }
  end

  def log_details(result, polling_record, original_status)
    ::Rails.logger.info(log_detail_hash(message: 'Form526 Submission, Form4142 polled status result', result:,
                                        polling_record:, original_status:))
  end

  def log_result(result, polling_record, original_status)
    StatsD.increment("#{STATS_KEY}.4142.#{result}")
    log_details(result, polling_record, original_status)
  end
end
