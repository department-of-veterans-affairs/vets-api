# frozen_string_literal: true

require 'csv'
require 'aws-sdk-s3'
require 'json'
require 'pdf_fill/filler'
require 'common/exceptions/parameter_missing'
require 'statsd-instrument'

# Usage:
#   bundle exec rails simple_forms_api:remediate_0781_only_submissions[submission_ids_csv_path]
#   (CSV must have a header row with 'submission_id')
#
# Or pass a comma/space-separated list of IDs:
#   bundle exec rails simple_forms_api:remediate_0781_only_submissions[123 456 789]

namespace :simple_forms_api do
  desc 'Remediate Form 0781-only submissions: generate PDFs, stamp, upload to S3, and print presigned URLs.'
  task :remediate_0781_only_submissions, [:input] => :environment do |_t, args|
    RemediateForm0781OnlySubmissions.new(args[:input]).process
  end
end

# Service class to handle the remediation process
class RemediateForm0781OnlySubmissions
  # Context object to encapsulate processing parameters
  ProcessingContext = Struct.new(
    :submission_id,
    :submission,
    :submission_date,
    :idx,
    :total,
    :form_id,
    :form_content,
    keyword_init: true
  )

  def initialize(input)
    @input = input
    raise Common::Exceptions::ParameterMissing, 'input (CSV path or IDs)' if @input.blank?

    @remediated     = []
    @not_found      = []
    @errored        = []
    @skipped        = []
    @presigned_urls = []
  end

  def process
    start_time = Time.current
    submission_ids = load_submission_ids
    puts "Processing #{submission_ids.size} submissions..."
    submission_ids.each_with_index do |submission_id, idx|
      process_submission(submission_id, idx, submission_ids.size)
    end
    print_summary

    # Emit DataDog metrics
    StatsD.increment('tasks.simple_forms_api.remediate_0781_only_submissions.started')
    StatsD.gauge('tasks.simple_forms_api.remediate_0781_only_submissions.total', submission_ids.size)
    StatsD.gauge('tasks.simple_forms_api.remediate_0781_only_submissions.remediated', @remediated.size)
    StatsD.gauge('tasks.simple_forms_api.remediate_0781_only_submissions.skipped',     @skipped.size)
    StatsD.gauge('tasks.simple_forms_api.remediate_0781_only_submissions.not_found',   @not_found.size)
    StatsD.gauge('tasks.simple_forms_api.remediate_0781_only_submissions.errored',     @errored.size)
    rem_ids = @remediated.map { |r| r[:submission_id] }.uniq
    StatsD.gauge(
      'tasks.simple_forms_api.remediate_0781_only_submissions.remediated_ids',
      rem_ids.size,
      tags: rem_ids.map { |id| "remediated_id:#{id}" }
    )
    StatsD.measure('tasks.simple_forms_api.remediate_0781_only_submissions.duration', Time.current - start_time)
  end

  private

  attr_reader :input

  def load_submission_ids
    if File.exist?(@input)
      ids = []
      CSV.foreach(@input, headers: true) { |row| ids << row['submission_id'] }
      ids.compact_blank
    else
      @input.to_s.split(/[,\s]+/).compact_blank
    end
  end

  def process_submission(submission_id, idx, total)
    submission = Form526Submission.find(submission_id)
    created_at = submission.created_at
    form_json  = JSON.parse(submission.form_to_json(Form526Submission::FORM_0781))

    get_form_keys(created_at).each do |key, form_id|
      content = form_json[key]
      next if content.blank?

      context = ProcessingContext.new(
        submission_id:,
        submission:,
        submission_date: created_at,
        idx:,
        total:,
        form_id:,
        form_content: content
      )
      handle_variant(context)
    end
  rescue ActiveRecord::RecordNotFound
    @not_found << submission_id
    puts "[#{idx + 1}/#{total}] Not found: #{submission_id}"
  rescue => e
    @errored << { submission_id:, error: e.message }
    Rails.logger.error("Error processing submission_id: #{submission_id}: #{e.message}")
    Rails.logger.error(e.backtrace.join("\n"))
    puts "[#{idx + 1}/#{total}] Error: #{submission_id}: #{e.message}"
  ensure
    cleanup_temp_files
  end

  def get_form_keys(date)
    if date < Date.new(2019, 6, 24)
      { 'form0781' => EVSS::DisabilityCompensationForm::SubmitForm0781::FORM_ID_0781 }
    else
      {
        'form0781' => EVSS::DisabilityCompensationForm::SubmitForm0781::FORM_ID_0781,
        'form0781v2' => EVSS::DisabilityCompensationForm::SubmitForm0781::FORM_ID_0781V2
      }
    end
  end

  def handle_variant(context)
    s3_key = build_s3_key(context.submission_id, context.form_id, context.submission_date)
    bucket = Settings.form0781_remediation.aws.bucket

    if s3_client.bucket(bucket).object(s3_key).exists?
      @skipped << { submission_id: context.submission_id, form_id: context.form_id, reason: 'PDF already exists in S3' }
      puts "[#{context.idx + 1}/#{context.total}] Skipped (exists): #{s3_key}"
      return
    end

    pdf_path = generate_stamped_pdf(context.submission, context.form_id, context.form_content)
    url      = upload_to_s3_and_presign(pdf_path, s3_key)

    @remediated     << { submission_id: context.submission_id, form_id: context.form_id }
    @presigned_urls << { submission_id: context.submission_id, form_id: context.form_id, url: }
    puts "[#{context.idx + 1}/#{context.total}] Uploaded: #{s3_key} => #{url}"
  end

  def s3_client
    Aws::S3::Resource.new(
      region: Settings.form0781_remediation.aws.region,
      access_key_id: ENV.fetch('evidence_remediation__aws__access_key_id', nil),
      secret_access_key: ENV.fetch('evidence_remediation__aws__secret_access_key', nil)
    )
  end

  def generate_stamped_pdf(submission, form_id, content)
    stamp_date = submission.created_at.in_time_zone('Central Time (US & Canada)')
    merged     = content.merge('signatureDate' => stamp_date)
    pdf        = PdfFill::Filler.fill_ancillary_form(merged, submission.submitted_claim_id, form_id)
    first      = PDFUtilities::DatestampPdf.new(pdf).run(text: 'VA.gov Submission', x: 510, y: 775, text_only: true)
    PDFUtilities::DatestampPdf.new(first).run(text: 'VA.gov', x: 5, y: 5, timestamp: stamp_date)
  end

  def upload_to_s3_and_presign(local_path, s3_key)
    obj = s3_client.bucket(Settings.form0781_remediation.aws.bucket).object(s3_key)
    obj.upload_file(local_path, content_type: 'application/pdf')
    obj.presigned_url(:get, expires_in: 7 * 24 * 60 * 60)
  end

  def build_s3_key(submission_id, form_id, date)
    "remediation/0781/#{date.strftime('%Y%m%d')}/#{submission_id}/#{form_id}.pdf"
  end

  def cleanup_temp_files
    Rails.root.glob('tmp/*.pdf').each do |file|
      File.delete(file)
    rescue => e
      Rails.logger.error("Failed to delete temp file #{file}: #{e.class}: #{e.message}")
    end
  end

  def print_summary
    puts "\n=== Remediation Summary ==="
    puts "Remediated (uploaded): #{@remediated.map { |r| "#{r[:submission_id]} (#{r[:form_id]})" }.join(', ')}"
    puts "Skipped (already exists): #{@skipped.map { |s| "#{s[:submission_id]} (#{s[:form_id]})" }.join(', ')}"
    puts "Not found: #{@not_found.join(', ')}"
    puts "Errored: #{@errored.map { |e| "#{e[:submission_id]} (#{e[:error]})" }.join(', ')}"
    puts "\nPresigned URLs:"
    @presigned_urls.each { |e| puts "#{e[:submission_id]},#{e[:form_id]},#{e[:url]}" }
    puts "\nRemediated Submission IDs: #{@remediated.map { |r| r[:submission_id] }.uniq.join(', ')}"
    puts '\nDone.'
  end
end
