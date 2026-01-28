# frozen_string_literal: true

# Purges PII/PHI from FormSubmission records and deletes S3 files
# after 60 days of successful submission to Lighthouse
#
# Retention Policy:
# - Triggers 60 days after lighthouse_updated_at (moment of success)
# - Only processes forms with aasm_state 'vbms' (successful)
# - Deletes S3 files and NULLs out PII fields
# - Keeps metadata (form_type, created_at, etc.)
#
# Schedule: After staging testing I will add to periodic jobs to run this daily. I think around ~3am

class FormUploadDataPurgeJob
  include Sidekiq::Job

  sidekiq_options retry: 3

  STATS_KEY = 'api.form_upload.data_purge'
  RETENTION_DAYS = 60
  BATCH_SIZE = 100

  FORM_UPLOAD_TYPES = %w[
    21-0779 21-4192 21-509 21-8940 21P-0516-1 21P-0517-1 21P-0518-1
    21P-0519C-1 21P-0519S-1 21P-530a 21P-8049 21-2680 21-674b 21-8951-2
    21-0788 21-4193 21P-4718a 21-4140 21P-4706c 21-8960 21-0304 21-651
    21P-4185
  ].freeze

  def perform
    StatsD.increment("#{STATS_KEY}.started")
    Rails.logger.info('FormUploadDataPurgeJob started')

    stats = initialize_stats
    purge_old_submissions(stats)

    record_metrics(stats)
    Rails.logger.info('FormUploadDataPurgeJob completed', stats)
  rescue => e
    handle_failure(e)
    raise
  end

  private

  def initialize_stats
    {
      form_submissions_purged: 0,
      s3_files_deleted: 0,
      s3_files_already_deleted: 0,
      errors: 0
    }
  end

  def purge_old_submissions(stats)
    cutoff_date = RETENTION_DAYS.days.ago

    loop do
      form_submissions = fetch_eligible_submissions(cutoff_date)
      break if form_submissions.empty?

      form_submissions.each { |fs| purge_form_submission(fs, stats) }
    end
  end

  def fetch_eligible_submissions(cutoff_date)
    FormSubmission
      .where(form_type: FORM_UPLOAD_TYPES)
      .joins(:form_submission_attempts)
      .where(form_submission_attempts: { aasm_state: 'vbms' })
      .where('form_submission_attempts.lighthouse_updated_at < ?', cutoff_date)
      .where.not(form_data_ciphertext: nil)
      .distinct
      .limit(BATCH_SIZE)
  end

  def purge_form_submission(form_submission, stats)
    vbms_attempt = form_submission.form_submission_attempts.first

    emit_pii_deleting_event(form_submission, vbms_attempt)

    form_data = JSON.parse(form_submission.form_data)
    purge_attachments(form_data, vbms_attempt&.benefits_intake_uuid, stats)
    purge_form_data(form_submission)

    emit_pii_deleted_event(form_submission, vbms_attempt)

    stats[:form_submissions_purged] += 1
    StatsD.increment("#{STATS_KEY}.form_purged", tags: ["form_type:#{form_submission.form_type}"])
  rescue => e
    stats[:errors] += 1
    Rails.logger.error(
      'Failed to purge form submission',
      form_submission_id: form_submission.id,
      form_type: form_submission.form_type,
      benefits_intake_uuid: vbms_attempt&.benefits_intake_uuid,
      backtrace: e.backtrace&.first(5)
    )
  end

  def purge_attachments(form_data, benefits_intake_uuid, stats)
    attachment_guids = collect_attachment_guids(form_data)
    if attachment_guids.empty?
      # logging this because we can get legacy records attachments through polling lighthouse
      Rails.logger.info(
        'No attachment guids found in form_data (legacy record)',
        benefits_intake_uuid:
      )
      return
    end
    attachment_guids.each { |guid| purge_attachment(guid, stats) }
  end

  def collect_attachment_guids(form_data)
    guids = [form_data['confirmation_code']]

    if form_data['supporting_documents'].is_a?(Array)
      guids += form_data['supporting_documents'].map do |doc|
        doc['confirmation_code']
      end
    end

    guids.compact
  end

  def purge_attachment(guid, stats)
    attachment = PersistentAttachment.find_by(guid:)
    return unless attachment

    delete_s3_file(attachment, stats)
  rescue => e
    stats[:errors] += 1
    Rails.logger.error('Failed to purge attachment', guid:, error: e.message)
  end

  def delete_s3_file(attachment, stats)
    unless attachment.file&.exists?
      stats[:s3_files_already_deleted] += 1
      Rails.logger.debug('S3 file already deleted', guid: attachment.guid)
      return
    end

    attachment.file.delete
    stats[:s3_files_deleted] += 1
    Rails.logger.info('S3 file deleted', guid: attachment.guid)
  rescue => e
    stats[:errors] += 1
    Rails.logger.info('Error while deleting S3 file', guid: attachment.guid, error: e.message)
  end

  def purge_form_data(form_submission)
    # rubocop:disable Rails/SkipsModelValidations
    form_submission.update_columns(
      form_data_ciphertext: nil,
      updated_at: Time.zone.now
    )

    # rubocop:enable Rails/SkipsModelValidations

    Rails.logger.info(
      'Form data purged',
      form_submission_id: form_submission.id,
      form_type: form_submission.form_type
    )
  end

  def emit_pii_deleting_event(form_submission, vbms_attempt)
    ActiveSupport::Notifications.instrument(
      'pii.deleting',
      {
        record_type: 'FormSubmission',
        form_submission_id: form_submission.id,
        form_type: form_submission.form_type,
        benefits_intake_uuid: vbms_attempt&.benefits_intake_uuid,
        submission_date: form_submission.created_at,
        lighthouse_updated_at: vbms_attempt&.lighthouse_updated_at,
        scheduled_for_deletion_at: Time.current
      }
    )
  end

  def emit_pii_deleted_event(form_submission, vbms_attempt)
    ActiveSupport::Notifications.instrument(
      'pii.deleted',
      {
        record_type: 'FormSubmission',
        form_submission_id: form_submission.id,
        form_type: form_submission.form_type,
        benefits_intake_uuid: vbms_attempt&.benefits_intake_uuid,
        submission_date: form_submission.created_at,
        lighthouse_updated_at: vbms_attempt&.lighthouse_updated_at,
        deleted_at: Time.current
      }
    )
  end

  def record_metrics(stats)
    StatsD.increment("#{STATS_KEY}.completed")
    StatsD.gauge("#{STATS_KEY}.form_submissions_purged", stats[:form_submissions_purged])
    StatsD.gauge("#{STATS_KEY}.s3_files_deleted", stats[:s3_files_deleted])
    StatsD.gauge("#{STATS_KEY}.s3_files_already_deleted", stats[:s3_files_already_deleted])
    StatsD.gauge("#{STATS_KEY}.errors", stats[:errors]) if stats[:errors].positive?
  end

  def handle_failure(exception)
    StatsD.increment("#{STATS_KEY}.failed")
    Rails.logger.error(
      'FormUploadDataPurgeJob failed',
      backtrace: exception.backtrace&.first(5)
    )
  end
end