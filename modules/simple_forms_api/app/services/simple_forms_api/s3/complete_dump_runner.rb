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

  def submissions
    @submissions ||= Form526Submission.where(id: submission_ids)
  end

  def submissions_by_uuid
    @submissions_by_uuid ||= group_submissions_by_uuid
  end

  # allows for deduplicating submissions per user on the next layer
  def group_submissions_by_uuid
    {}.tap do |collection|
      submissions.pluck(:user_uuid).uniq.each do |uuid|
        collection[uuid] = Form526Submission.where(user_uuid: uuid, id: submission_ids).pluck(:id)
      end
    end
  end

  def run
    if bundle_by_user
      submissions_by_uuid.each do |uuid, submission_ids|
        Rails.logger.info(
          "Processing for user: #{uuid} with #{submission_ids&.count} submission(s)",
          { uuid:, submission_ids: }
        )
        UserSubmissionDumpBuilder.new(uuid:, submission_ids:, parent_dir:).run
      rescue => e
        raise unless run_quiet

        Rails.logger.error("User failure: #{uuid}", { uuid:, error: e })
        failures << { uuid:, error: e }
      end
    else
      submissions.each_with_index do |sub, idx|
        Rails.logger.info(
          "Processing submission: #{sub.id} (non-grouped) # #{idx + 1} of #{submissions.count} total submissions", {
            submission_id: sub.id, submission_count: submissions.count
          }
        )
        DumpSubmissionToPdf.new(submission_id: sub.id, parent_dir:, quiet_pdf_failures:, quiet_upload_failures:).run
      rescue => e
        raise unless run_quiet

        failures << { submission_id: id, error: e }
      end
    end
    parent_dir
  end

  def clear_tmp
    system('rm -f tmp/* > /dev/null 2>&1')
  end

  def s3_resource
    @s3_resource ||= Reports::Uploader.new_s3_resource
  end

  def target_bucket
    @target_bucket ||= Reports::Uploader.s3_bucket
  end
end
