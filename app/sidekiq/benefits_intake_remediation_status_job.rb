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

  def debug(msg)
    puts
    puts "#{msg}"
    puts
  end

  def perform
    Rails.logger.info('BenefitsIntakeRemediationStatusJob started')

    form_submissions = FormSubmission.includes(:form_submission_attempts)
    submissions = form_submissions.all.group_by { |fs| fs.saved_claim_id }
    failures = submissions.map { |claim_id, fs|
      fs.sort_by! { |_fs| _fs.created_at }
      attempts = fs.map(&:form_submission_attempts).flatten.sort_by { |_att| _att.created_at }
      vbms = attempts.find { |att| att.aasm_state == 'vbms' }
      pending = attempts.find { |att| att.aasm_state == 'pending' }
      !(vbms || pending) ? fs.last : nil
    }.compact

    batch_process(failures) unless failures.empty?

    record_unsubmitted_and_orphaned

    Rails.logger.info('BenefitsIntakeRemediationStatusJob ended', total_handled:)
  end

  private

  attr_reader :batch_size
  attr_accessor :total_handled

  def record_unsubmitted_and_orphaned
    form_submission_groups = FormSubmission.all.group_by { |fs| fs.form_type }

    form_submission_groups.each do |form_id, submissions|
      fs_saved_claim_ids = submissions.map(&:saved_claim_id).uniq

      claims = SavedClaim.where(form_id:).where('created_at >= ?', submissions.minimum(:created_at))
      claim_ids = claims.map(&:id).uniq

      unsubmitted = claim_ids - fs_saved_claim_ids
      orphaned = fs_saved_claim_ids - claim_ids

      failures = submissions.group_by { |fs| fs.saved_claim_id }
      failures.reject! { |claim_id, fs|
        attempts = fs.map(&:form_submission_attempts).flatten.sort_by { |_att| _att.created_at }
        vbms = attempts.find { |att| att.aasm_state == 'vbms' }
        pending = attempts.find { |att| att.aasm_state == 'pending' }
        vbms || pending
      }

      StatsD.set("#{STATS_KEY}.#{form_id}.unsubmitted_claims", unsubmitted.length)
      StatsD.set("#{STATS_KEY}.#{form_id}.orphaned_submissions", orphaned.length)
      StatsD.set("#{STATS_KEY}.#{form_id}.outstanding_failures", failures.length)
      Rails.logger.info("BenefitsIntakeRemediationStatusJob submission audit #{form_id}", form_id:, unsubmitted:, orphaned:, failures:)
    end
  end

  def batch_process(failures)
    intake_service = BenefitsIntake::Service.new

    failures.each_slice(batch_size) do |batch|
      batch_uuids = batch.map(&:benefits_intake_uuid)
      Rails.logger.info('BenefitsIntakeRemediationStatusJob processing batch', batch_uuids:)

      response = intake_service.bulk_status(uuids: batch_uuids)
      raise response.body unless response.success?

      next unless data = response.body['data']

      handle_response(data, batch)
    end
  rescue => e
    Rails.logger.error('BenefitsIntakeRemediationStatusJob ERROR processing batch', class: self.class.name, message: e.message)
  end

  def handle_response(response_data, failure_batch)
    response_data.each do |submission|
      uuid = submission['id']
      form_submission = failure_batch.find do |submission_from_db|
        submission_from_db.benefits_intake_uuid == uuid
      end
      form_id = form_submission.form_type

      form_submission_attempt = form_submission.form_submission_attempts.last

      # https://developer.va.gov/explore/api/benefits-intake/docs
      status = submission.dig('attributes', 'status')
      if status == 'vbms'
        # submission was successfully uploaded into a Veteran's eFolder within VBMS
        form_submission_attempt.remediate!
      end

      total_handled += 1
    end
  end

end
