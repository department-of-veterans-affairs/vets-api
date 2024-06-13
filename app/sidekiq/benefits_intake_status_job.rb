# frozen_string_literal: true

require 'lighthouse/benefits_intake/service'

class BenefitsIntakeStatusJob
  include Sidekiq::Job

  sidekiq_options retry: false

  STATS_KEY = 'api.benefits_intake.submission_status'
  STALE_SLA = Settings.lighthouse.benefits_intake.report.stale_sla || 10
  BATCH_SIZE = Settings.lighthouse.benefits_intake.report.batch_size || 1000

  attr_reader :batch_size

  def initialize(batch_size: BATCH_SIZE)
    @batch_size = batch_size
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

  def batch_process(pending_form_submissions)
    total_handled = 0
    intake_service = BenefitsIntake::Service.new

    pending_form_submissions.each_slice(batch_size) do |batch|
      batch_uuids = batch.map(&:benefits_intake_uuid)
      response = intake_service.bulk_status(uuids: batch_uuids)
      raise response.body unless response.success?

      total_handled += handle_response(response, batch)
    end

    [total_handled, true]
  rescue => e
    Rails.logger.error('Error processing Intake Status batch', class: self.class.name, message: e.message)
    [total_handled, false]
  end

  # rubocop:disable Metrics/MethodLength
  def handle_response(response, pending_form_submissions)
    total_handled = 0

    response.body['data']&.each do |submission|
      uuid = submission['id']
      form_submission = pending_form_submissions.find do |submission_from_db|
        submission_from_db.benefits_intake_uuid == uuid
      end
      form_id = form_submission.form_type

      form_submission_attempt = form_submission.latest_pending_attempt
      time_to_transition = (Time.zone.now - form_submission_attempt.created_at).truncate

      status = submission.dig('attributes', 'status')
      if %w[error expired].include?(status)
        form_submission_attempt.fail!
        log_result('failure', form_id, uuid, time_to_transition)
      elsif status == 'vbms'
        form_submission_attempt.vbms!
        log_result('success', form_id, uuid, time_to_transition)
      elsif time_to_transition > STALE_SLA.days
        log_result('stale', form_id, uuid, time_to_transition)
      else
        log_result('pending', form_id, uuid)
      end

      total_handled += 1
    end

    total_handled
  end
  # rubocop:enable Metrics/MethodLength

  def log_result(result, form_id, uuid, time_to_transition = nil)
    StatsD.increment("#{STATS_KEY}.#{form_id}.#{result}")
    StatsD.increment("#{STATS_KEY}.all_forms.#{result}")
    Rails.logger.info('BenefitsIntakeStatusJob', result:, form_id:, uuid:, time_to_transition:)
  end
end
