# frozen_string_literal: true

class CompleteDumpRunner
  attr_reader :submission_ids, :parent_dir, :successes, :failures,
              :bundle_by_user, :run_quiet, :quiet_upload_failures, :quiet_pdf_failures

  def initialize(submission_ids:,
                 parent_dir: 'wipn8923-test',
                 bundle_by_user: true,
                 run_quiet: true,
                 quiet_upload_failures: false,
                 quiet_pdf_failures: false,
                 signed_link: false)
    @submission_ids = submission_ids
    @parent_dir = parent_dir
    @bundle_by_user = bundle_by_user
    @run_quiet = run_quiet # silence but record errors until the end
    @quiet_upload_failures = quiet_upload_failures # granular control over how user processing raises errors
    @quiet_pdf_failures = quiet_pdf_failures # granular control over how user processing raises errors
    @failures = []
  end

  def run
    bundle_by_user ? process_by_user : process_individual_submissions
    cleanup_tmp_files
    parent_dir
  end

  private

  def submissions
    @submissions ||= Form526Submission.where(id: submission_ids)
  end

  def submissions_by_uuid
    @submissions_by_uuid ||= group_submissions_by_uuid
  end

  # Group submissions by user_uuid for easier bundling
  def group_submissions_by_uuid
    submissions.group_by(&:user_uuid).transform_values do |user_submissions|
      user_submissions.map(&:id)
    end
  end

  def process_by_user
    submissions_by_uuid.each do |uuid, submission_ids|
      log_info("Processing for user: #{uuid} with #{submission_ids.size} submission(s)", uuid:, submission_ids:)
      process_user_submissions(uuid, submission_ids)
    end
  end

  def process_individual_submissions
    submissions.each_with_index do |sub, idx|
      log_info("Processing submission: #{sub.id} (non-grouped) ##{idx + 1} of #{submissions.count} total submissions",
               submission_id: sub.id, submission_count: submissions.count)
      process_submission(sub.id)
    end
  end

  def process_user_submissions(uuid, submission_ids)
    UserSubmissionDumpBuilder.new(uuid:, submission_ids:, parent_dir:).run
  rescue => e
    handle_error("User failure: #{uuid}", e, uuid:)
  end

  def process_submission(submission_id)
    DumpSubmissionToPdf.new(
      submission_id:,
      parent_dir:,
      quiet_pdf_failures:,
      quiet_upload_failures:
    ).run
  rescue => e
    handle_error("Submission failure: #{submission_id}", e, submission_id:)
  end

  def handle_error(message, error, context)
    raise unless run_quiet

    log_error(message, error, context)
    failures << { context => error }
  end

  def cleanup_tmp_files
    system('rm -f tmp/* > /dev/null 2>&1')
  end

  def log_info(message, **details)
    Rails.logger.info(message, details)
  end

  def log_error(message, error, **details)
    Rails.logger.error(message, details.merge(error: error.message, backtrace: error.backtrace.first(5)))
  end

  def s3_resource
    @s3_resource ||= Reports::Uploader.new_s3_resource
  end

  def target_bucket
    @target_bucket ||= Reports::Uploader.s3_bucket
  end
end
