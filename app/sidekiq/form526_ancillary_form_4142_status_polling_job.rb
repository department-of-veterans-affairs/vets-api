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
      log_result('true_success')
      form_submission.accepted!
    elsif status == 'success'
      log_result('paranoid_success')
      form_submission.paranoid_success!
    else
      Rails.logger.info(
        'Unknown or incomplete status returned from Benefits Intake API for 526 submission',
        status:,
        submission_id: form_submission.id
      )
    end
  end


  def log_details(result) 
    ::Rails.logger.info({
      form_id: Form526Submission::FORM_4142,
      parent_form_id: Form526Submission::FORM_526,
      message: 'Form526 Submission, Form4142 polled status result',
      submission_id:,
      lighthouse_submission: {
        id: 
      }
    })
  end


  def log_result(result)
    StatsD.increment("#{STATS_KEY}.526.#{result}")
    StatsD.increment("#{STATS_KEY}.4142.#{result}")
    log_details(result)
  end



end
