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
    failures = outstanding_failures(form_submissions.all)

    batch_process(failures) unless failures.empty?

    submission_audit

    Rails.logger.info('BenefitsIntakeRemediationStatusJob ended', total_handled:)
  end

  private

  attr_reader :batch_size
  attr_accessor :total_handled

  def outstanding_failures(submissions)
    failures = submissions.group_by(&:saved_claim_id)
    failures.map do |_claim_id, fs|
      fs.sort_by!(&:created_at)
      attempts = fs.map(&:form_submission_attempts).flatten.sort_by(&:created_at)
      not_failure = attempts.find { |att| att.aasm_state != 'failure' }
      not_failure ? nil : fs.last
    end.compact
  end

  def batch_process(failures)
    intake_service = BenefitsIntake::Service.new

    failures.each_slice(batch_size) do |batch|
      batch_uuids = batch.map(&:benefits_intake_uuid)
      Rails.logger.info('BenefitsIntakeRemediationStatusJob processing batch', batch_uuids:)

      response = intake_service.bulk_status(uuids: batch_uuids)
      raise response.body unless response.success?

      next unless (data = response.body['data'])

      handle_response(data, batch)
    end
  rescue => e
    Rails.logger.error('BenefitsIntakeRemediationStatusJob ERROR processing batch', class: self.class.name,
                                                                                    message: e.message)
  end

  def handle_response(response_data, failure_batch)
    response_data.each do |submission|
      uuid = submission['id']
      form_submission = failure_batch.find do |submission_from_db|
        submission_from_db.benefits_intake_uuid == uuid
      end
      form_submission.form_type

      form_submission_attempt = form_submission.form_submission_attempts.last

      # https://developer.va.gov/explore/api/benefits-intake/docs
      status = submission.dig('attributes', 'status')
      lighthouse_updated_at = submission.dig('attributes', 'updated_at')
      if status == 'vbms'
        # submission was successfully uploaded into a Veteran's eFolder within VBMS
        form_submission_attempt.update(lighthouse_updated_at:)
        form_submission_attempt.remediate!
      end

      total_handled + 1
    end
  end

  def submission_audit
    form_submissions = FormSubmission.includes(:form_submission_attempts)
    form_submission_groups = form_submissions.all.group_by(&:form_type)

    form_submission_groups.each do |form_id, submissions|
      fs_saved_claim_ids = submissions.map(&:saved_claim_id).uniq

      claims = SavedClaim.where(form_id:).where('id >= ?', fs_saved_claim_ids.min)
      claim_ids = claims.map(&:id).uniq

      unsubmitted = claim_ids - fs_saved_claim_ids
      orphaned = fs_saved_claim_ids - claim_ids

      failures = outstanding_failures(submissions)
      failures = failures.group_by(&:saved_claim_id)
      failures.each do |claim_id, fs|
        last_attempt = fs.form_submission_attempts.max_by(&:created_at)
        failures[claim_id] = [fs.benefits_intake_uuid, last_attempt.error_message]
      end

      StatsD.set("#{STATS_KEY}.#{form_id}.unsubmitted_claims", unsubmitted.length)
      StatsD.set("#{STATS_KEY}.#{form_id}.orphaned_submissions", orphaned.length)
      StatsD.set("#{STATS_KEY}.#{form_id}.outstanding_failures", failures.length)
      Rails.logger.info("BenefitsIntakeRemediationStatusJob submission audit #{form_id}", form_id:, unsubmitted:,
                                                                                          orphaned:, failures:)
    end
  end
end
