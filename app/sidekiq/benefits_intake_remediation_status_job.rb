# frozen_string_literal: true

require 'lighthouse/benefits_intake/service'

# Reporting job for Lighthouse Benefit Intake Failures
# @see https://vagov.ddog-gov.com/dashboard/8zk-ja2-xvm/benefits-intake-submission-remediation-report
class BenefitsIntakeRemediationStatusJob
  include Sidekiq::Job

  sidekiq_options retry: false

  # metrics key
  STATS_KEY = 'api.benefits_intake.remediation_status'

  # job batch size
  BATCH_SIZE = Settings.lighthouse.benefits_intake.report.batch_size || 1000

  # create an instance
  def initialize(batch_size: BATCH_SIZE)
    @batch_size = batch_size
    @total_handled = 0
  end

  # search all submissions for outstanding failures
  # poll LH endpoint to see if status has changed (case if endpoint had an error initially)
  # report stats on submissions, grouped by form-type
  def perform(form_id = nil)
    Rails.logger.info('BenefitsIntakeRemediationStatusJob started')

    form_submissions = FormSubmission.includes(:form_submission_attempts)
    failures = outstanding_failures(form_submissions.all)

    # filter running this job to a specific form_id/form_type
    @form_id = form_id
    failures.select! { |f| f.form_type == form_id } if form_id

    batch_process(failures) unless failures.empty?

    submission_audit

    Rails.logger.info('BenefitsIntakeRemediationStatusJob ended', total_handled:)
  rescue => e
    # catch and log, but not re-raise to avoid sidekiq exhaustion alerts
    Rails.logger.error('BenefitsIntakeRemediationStatusJob ERROR', class: self.class.name, message: e.message)
  end

  private

  attr_reader :batch_size, :total_handled, :form_id

  # determine if a claim has an outstanding failure
  # each claim can have multiple FormSubmission, which can have multiple FormSubmissionAttempt
  # conflate these and search for a non-failure, which rejects the claim from the list
  #
  # @param submissions [Array<FormSubmission>]
  #
  def outstanding_failures(submissions)
    failures = submissions.group_by(&:saved_claim_id)
    failures.map do |_claim_id, fs|
      fs.sort_by!(&:created_at)
      attempts = fs.map(&:form_submission_attempts).flatten.sort_by(&:created_at)
      not_failure = attempts.find { |att| att.aasm_state != 'failure' }
      not_failure ? nil : fs.last
    end.compact
  end

  # perform a bulk_status check in Lighthouse to retrieve current statuses
  # a processing error will abort the job (no retries)
  #
  # @param failures [Array<FormSubmission>] submissions with only 'failure' statuses
  #
  def batch_process(failures)
    intake_service = BenefitsIntake::Service.new

    failures.each_slice(batch_size) do |batch|
      batch_uuids = batch.map { |submission| submission.latest_attempt&.benefits_intake_uuid }
      Rails.logger.info('BenefitsIntakeRemediationStatusJob processing batch', batch_uuids:)

      response = intake_service.bulk_status(uuids: batch_uuids)
      raise response.body unless response.success?

      next unless (data = response.body['data'])

      handle_response(data, batch)
    end
  end

  # process response from Lighthouse to update outstanding failures
  #
  # @param response_date [Hash] Lighthouse Benefits Intake API response
  # @param failure_batch [Array<FormSubmission>] current batch being processed
  #
  def handle_response(response_data, failure_batch)
    response_data.each do |submission|
      uuid = submission['id']
      form_submission = failure_batch.find do |submission_from_db|
        submission_from_db.latest_attempt&.benefits_intake_uuid == uuid
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

      @total_handled = total_handled + 1
    end
  end

  # gather metrics - grouped by form type
  # @see #submission_audit_metrics
  def submission_audit
    # requery form_submissions in case there was an update
    form_submissions = FormSubmission.includes(:form_submission_attempts)
    form_submission_groups = form_submissions.all.group_by(&:form_type)

    form_submission_groups.each do |form_type, submissions|
      next if form_id && form_id != form_type

      fs_saved_claim_ids = submissions.map(&:saved_claim_id).uniq.compact
      next unless (earliest = fs_saved_claim_ids.min)

      claims = SavedClaim.where(form_id: form_type).where('id >= ?', earliest)
      claim_ids = claims.map(&:id).uniq

      unsubmitted = claim_ids - fs_saved_claim_ids
      orphaned = fs_saved_claim_ids - claim_ids

      failures = outstanding_failures(submissions)
      failures.map! do |fs|
        { claim_id: fs.saved_claim_id, uuid: fs.latest_attempt.benefits_intake_uuid,
          error_message: fs.latest_attempt.error_message }
      end

      submission_audit_metrics(form_type, unsubmitted, orphaned, failures)
    end
  end

  # report metrics
  #
  # @param form_type [String] the saved_claim form id
  # @param unsubmitted [Array<Integer>] list of SavedClaim ids that do not have a FormSubmission record
  # @param orphaned [Array<Integer>] list of saved_claim_ids with a FormSubmission, but no SavedClaim
  # @param failures [Array<Hash>] list of outstanding failures (claim.id, benefits_intake_uuid, error_message)
  def submission_audit_metrics(form_type, unsubmitted, orphaned, failures)
    audit_log = "BenefitsIntakeRemediationStatusJob submission audit #{form_type}"
    StatsD.gauge("#{STATS_KEY}.unsubmitted_claims", unsubmitted.length, tags: ["form_id:#{form_type}"])
    StatsD.gauge("#{STATS_KEY}.orphaned_submissions", orphaned.length, tags: ["form_id:#{form_type}"])
    StatsD.gauge("#{STATS_KEY}.outstanding_failures", failures.length, tags: ["form_id:#{form_type}"])
    Rails.logger.info(audit_log, form_id: form_type, unsubmitted:, orphaned:, failures:)
  end
end
