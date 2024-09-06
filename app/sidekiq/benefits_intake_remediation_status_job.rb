# frozen_string_literal: true

require 'lighthouse/benefits_intake/service'

class BenefitsIntakeRemediationStatusJob
  include Sidekiq::Job

  sidekiq_options retry: false

  STATS_KEY = 'api.benefits_intake.remediation_status'
  BATCH_SIZE = Settings.lighthouse.benefits_intake.report.batch_size || 1000

  def initialize(batch_size: BATCH_SIZE)
    @batch_size = batch_size
    @total_handled = 0
  end

  def perform
    Rails.logger.info('BenefitsIntakeRemediationStatusJob started')

    form_submissions = FormSubmission.includes(:form_submission_attempts)
    fs_saved_claim_ids = form_submissions.map(&:saved_claim_id).uniq

    started = form_submissions.group(:form_type).minimum(:created_at)
    started.each do |form_id, created_at|
      claim_ids = SavedClaim.where(form_id:).where("created_at > ?", created_at:).map(&:id).uniq


      puts "UNSUBMITTED CLAIMS: #{claim_ids - fs_saved_claim_ids}"
      puts "ORPHAN SUBMISSION: #{fs_saved_claim_ids - claim_ids}"
    end

    failed = form_submissions.where(form_submission_attempts: {aasm_state: 'failure'})

    batch_process(submissions)

    Rails.logger.info('BenefitsIntakeRemediationStatusJob ended', total_handled:)
  end

  private

  attr_reader :batch_size
  attr_accessor :total_handled

  def batch_process(submissions)
    intake_service = BenefitsIntake::Service.new

    submissions.each_slice(batch_size) do |batch|
      batch_uuids = batch.map(&:benefits_intake_uuid)
      response = intake_service.bulk_status(uuids: batch_uuids)
      raise response.body unless response.success?

      next unless data = response.body['data']

      handle_response(data, batch)
    end

  rescue => e
    Rails.logger.error('Error processing Intake Status batch', class: self.class.name, message: e.message)
  end

  # rubocop:disable Metrics/MethodLength
  def handle_response(response_data, form_submissions)
    response_data.each do |submission|
      uuid = submission['id']
      form_submission = form_submissions.find do |submission_from_db|
        submission_from_db.benefits_intake_uuid == uuid
      end
      form_id = form_submission.form_type

      form_submission_attempt = form_submission.latest_pending_attempt

      # https://developer.va.gov/explore/api/benefits-intake/docs
      status = submission.dig('attributes', 'status')
      if %w[error expired].include?(status)
        # Error - Indicates that there was an error. Refer to the error code and detail for further information.
        # Expired - Indicate that documents were not successfully uploaded within the 15-minute window.
        form_submission_attempt.fail!
        log_result('failure', form_id, uuid, time_to_transition)
      elsif status == 'vbms'
        # submission was successfully uploaded into a Veteran's eFolder within VBMS
        form_submission_attempt.vbms!
        log_result('success', form_id, uuid, time_to_transition)
      elsif time_to_transition > STALE_SLA.days
        # exceeds SLA (service level agreement) days for submission completion
        log_result('stale', form_id, uuid, time_to_transition)
      else
        # no change being tracked
        log_result('pending', form_id, uuid)
      end

      total_handled += 1
    end
  end
  # rubocop:enable Metrics/MethodLength

  def log_result(result, form_id, uuid, time_to_transition = nil)
    StatsD.increment("#{STATS_KEY}.#{form_id}.#{result}")
    StatsD.increment("#{STATS_KEY}.all_forms.#{result}")
    Rails.logger.info('BenefitsIntakeRemediationStatusJob', result:, form_id:, uuid:, time_to_transition:)
  end
end
