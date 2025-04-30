# frozen_string_literal: true

require 'csv'
require 'aws-sdk-s3'
require 'json'
require 'common/exceptions/parameter_missing'
require 'statsd-instrument'
require 'simple_forms_api/form_remediation/configuration/form_0781_config'
require_relative '../../app/services/simple_forms_api/form_remediation/jobs/archive_batch_processing_job'

# Usage:
#   bundle exec rails simple_forms_api:remediate_0781_only_submissions[submission_ids_csv_path]
#   (CSV must have a header row with 'submission_id')
#
# Or pass a comma/space-separated list of IDs:
#   bundle exec rails simple_forms_api:remediate_0781_only_submissions[123 456 789]

def validate_input!(ids)
  raise Common::Exceptions::ParameterMissing, 'submission_ids' unless ids&.any?
end

def load_submission_ids(input)
  if File.exist?(input)
    ids = []
    CSV.foreach(input, headers: true) { |row| ids << row['submission_id'] }
    ids.compact_blank
  else
    input.to_s.split(/[,\s]+/).compact_blank
  end
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

namespace :simple_forms_api do
  desc 'Remediate Form 0781/0781V2 submissions via the unified pipeline'
  task :remediate_0781_only_submissions, [:input] => :environment do |_, args|
    start_time = Time.current
    input = args[:input]
    raise Common::Exceptions::ParameterMissing, 'input' if input.blank?

    submission_ids = load_submission_ids(input)
    validate_input!(submission_ids)

    Rails.logger.info("Processing #{submission_ids.size} submissions...")

    results = { processed: [], skipped: [], not_found: [], errored: [] }
    job = SimpleFormsApi::FormRemediation::Jobs::ArchiveBatchProcessingJob.new

    # Process each submission ID
    submission_ids.each_with_index do |submission_id, idx|
      submission = Form526Submission.find(submission_id)
      created_at = submission.created_at
      form_json = JSON.parse(submission.form_to_json(Form526Submission::FORM_0781))

      # Process each form type based on the submission date
      get_form_keys(created_at).each do |form_key, form_id|
        form_content = form_json[form_key]
        next if form_content.blank?

        puts "[#{idx + 1}/#{submission_ids.size}] Processing #{submission_id} with form #{form_key} (#{form_id})"

        # Create a configuration specific to this form type
        config = SimpleFormsApi::FormRemediation::Configuration::Form0781Config.new(
          form_key:,
          form_id:
        )

        # Process the submission through the unified pipeline
        presigned_urls = job.perform(ids: [submission_id], config:, type: :remediation)

        if presigned_urls&.any?
          results[:processed] << {
            submission_id:,
            form_key:,
            form_id:,
            url: presigned_urls.first
          }
          puts "[#{idx + 1}/#{submission_ids.size}] Successfully processed: #{submission_id} (#{form_key})"
        else
          results[:skipped] << { submission_id:, form_key:, form_id: }
          puts "[#{idx + 1}/#{submission_ids.size}] No URLs returned, possibly skipped: #{submission_id} (#{form_key})"
        end
      end
    rescue ActiveRecord::RecordNotFound
      results[:not_found] << submission_id
      puts "[#{idx + 1}/#{submission_ids.size}] Not found: #{submission_id}"
    rescue => e
      results[:errored] << { submission_id:, error: e.message }
      Rails.logger.error("Error processing submission_id: #{submission_id}: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      puts "[#{idx + 1}/#{submission_ids.size}] Error: #{submission_id}: #{e.message}"
    end

    # Print summary
    puts "\n=== Remediation Summary ==="
    puts "Processed: #{results[:processed].map { |r| "#{r[:submission_id]} (#{r[:form_key]})" }.join(', ')}"
    puts "Skipped: #{results[:skipped].map { |s| "#{s[:submission_id]} (#{s[:form_key]})" }.join(', ')}"
    puts "Not found: #{results[:not_found].join(', ')}"
    puts "Errored: #{results[:errored].map { |e| "#{e[:submission_id]} (#{e[:error]})" }.join(', ')}"

    puts "\nPresigned URLs:"
    results[:processed].each { |e| puts "#{e[:submission_id]},#{e[:form_key]},#{e[:form_id]},#{e[:url]}" }

    # Emit DataDog metrics
    StatsD.increment('tasks.simple_forms_api.remediate_0781_only_submissions.started')
    StatsD.gauge('tasks.simple_forms_api.remediate_0781_only_submissions.total', submission_ids.size)
    StatsD.gauge('tasks.simple_forms_api.remediate_0781_only_submissions.processed', results[:processed].size)
    StatsD.gauge('tasks.simple_forms_api.remediate_0781_only_submissions.skipped', results[:skipped].size)
    StatsD.gauge('tasks.simple_forms_api.remediate_0781_only_submissions.not_found', results[:not_found].size)
    StatsD.gauge('tasks.simple_forms_api.remediate_0781_only_submissions.errored', results[:errored].size)

    processed_ids = results[:processed].map { |r| r[:submission_id] }.uniq
    StatsD.gauge(
      'tasks.simple_forms_api.remediate_0781_only_submissions.processed_ids',
      processed_ids.size,
      tags: processed_ids.map { |id| "processed_id:#{id}" }
    )
    StatsD.measure('tasks.simple_forms_api.remediate_0781_only_submissions.duration', Time.current - start_time)

    puts "\nDone."
  end
end
