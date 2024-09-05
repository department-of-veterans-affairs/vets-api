# frozen_string_literal: true

class UserSubmissionDumpBuilder
  attr_reader :uuid, :user_dir, :submission_ids

  def initialize(uuid:, submission_ids:, parent_dir: 'wipn8923-test')
    @submission_ids = submission_ids
    @uuid = uuid
    @user_dir = build_user_directory(parent_dir)
  end

  def run
    log_info("Starting dump for user: #{uuid}, Submissions: #{submission_ids}")
    write_user_submissions
    log_info("Dump completed for user: #{uuid}")
    user_dir
  rescue => e
    log_error("Error in dump process for user: #{uuid}", e)
    raise e
  end

  private

  def build_user_directory(parent_dir)
    "#{parent_dir}/#{uuid}"
  end

  def write_user_submissions
    submissions.each do |submission|
      dump_submission(submission)
    rescue => e
      log_error("Failed to dump submission: #{submission.id} for user: #{uuid}", e)
    end
  end

  def dump_submission(submission)
    log_info("Processing submission: #{submission.id}")
    DumpSubmissionToPdf.new(submission:, parent_dir: user_dir).run
  end

  def submissions
    @submissions ||= fetch_submissions
  end

  def fetch_submissions
    FormSubmission.where(id: submission_ids).tap do |subs|
      log_info("Fetched #{subs.count} submissions for user: #{uuid}")
    end
  end

  def s3_resource
    @s3_resource ||= Reports::Uploader.new_s3_resource
  end

  def target_bucket
    @target_bucket ||= Reports::Uploader.s3_bucket
  end

  def log_info(message)
    Rails.logger.info(message)
  end

  def log_error(message, error)
    Rails.logger.error("#{message}. Error: #{error.message}")
  end
end
