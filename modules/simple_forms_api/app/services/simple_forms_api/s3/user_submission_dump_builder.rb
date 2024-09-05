# frozen_string_literal: true

class UserSubmissionDumpBuilder
  attr_reader :uuid, :user_dir, :links, :submission_ids

  def initialize(uuid:, submission_ids:, parent_dir: 'wipn8923-test')
    @submission_ids = submission_ids
    @uuid = uuid
    @user_dir = "#{parent_dir}/#{uuid}"
    @links = []
  end

  def run
    write_user_submissions
    # write_dedupe_files
    user_dir
  end

  def write_user_submissions
    submissions.each do |submission|
      DumpSubmissionToPdf.new(submission:, parent_dir: user_dir).run
    end
  end

  def submissions
    @submissions ||= Form526Submission.where(id: submission_ids)
  end

  def write_dedupe_files
    content = "The following mismatched form data was identified for user (uuid): #{uuid}\n"
    if dedupe_report_for_user.blank?
      content << "\nNo variations in users submissions! \n"
    else
      dedupe_report_for_user.each do |key_chain, diff|
        next if diff.blank?

        content << "\tnested under form keys #{key_chain.join(' -> ')}...\n"
        diff.each do |value, submission_ids|
          content << "\t\tthese submissions: #{submission_ids.join(', ')}\n"
          content << "\t\t\thave a value of: '#{value}'\n"
        end
      end
    end
    s3_resource.bucket(target_bucket)
               .object("#{user_dir}/duplicate_report_pretty.txt")
               .put(body: content)
    s3_resource.bucket(target_bucket)
               .object("#{user_dir}/duplicate_report.json")
               .put(body: dedupe_report_for_user.to_json)
  end

  def dedupe_report_for_user
    @dedupe_report_for_user ||= SubmissionDuplicateReport.new(submission_ids:).run[uuid]
  end

  def s3_resource
    @s3_resource ||= Reports::Uploader.new_s3_resource
  end

  def target_bucket
    @target_bucket ||= Reports::Uploader.s3_bucket
  end
end
