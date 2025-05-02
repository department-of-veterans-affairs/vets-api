# frozen_string_literal: true

require 'csv'
require 'aws-sdk-s3'
require 'json'
require 'common/exceptions/parameter_missing'
require 'statsd-instrument'
require 'simple_forms_api/form_remediation/configuration/form_0781_config'
require_relative '../../app/services/simple_forms_api/form_remediation/jobs/archive_batch_processing_job'
require_relative 'dev/remediation_stubs' if Rails.env.development?

# Usage:
#   Production:
#     bundle exec rails simple_forms_api:remediate_0781_and_0781v2_forms[submission_ids_csv_path]
#     (CSV must have a header row with 'submission_id')
#
#   Or pass a comma/space-separated list of IDs:
#     bundle exec rails simple_forms_api:remediate_0781_and_0781v2_forms[123 456 789]
#
#   Local Development:
#     1. Ensure you have a Form526Submission in your local database:
#        - Your local seeds should include Form526Submission.find(1)
#        - Or create one manually in rails console
#     2. Run: bundle exec rails "simple_forms_api:remediate_0781_and_0781v2_forms[1]"
#
# Description:
# This task remediates both Form 0781 and Form 0781v2 submissions from the broader dataset
# of affected claims (21-0781_submissions_20241017b). The task automatically handles structural
# differences in form layout based on submission date.
#
# For submissions before June 24, 2019, only Form 0781 is processed.
# For submissions on or after that date, both Form 0781 and Form 0781v2 are processed.
#
# Related: https://github.com/department-of-veterans-affairs/evidence-upload-remediation/issues/43
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
  desc 'Remediate Form 0781 and 0781v2 submissions via the unified pipeline, with date-based form handling'
  task :remediate_0781_and_0781v2_forms, [:input] => :environment do |_, args|
    SimpleFormsApi::Dev::RemediationStubs.apply if Rails.env.development?

    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    input = args[:input]
    raise Common::Exceptions::ParameterMissing, 'input' if input.blank?

    submission_ids = load_submission_ids(input)
    validate_input!(submission_ids)

    StatsD.increment('tasks.simple_forms_api.remediate_0781_and_0781v2_forms.started')

    Rails.logger.info("Processing #{submission_ids.size} submissions for 0781/0781v2 remediation ...")

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
        if form_content.blank?
          results[:skipped] << {
            submission_id:,
            form_key:,
            reason: 'blank_form_content'
          }
          puts "[#{idx + 1}/#{submission_ids.size}] Skipped: #{submission_id} (#{form_key}) - blank form content"
          next
        end

        puts "[#{idx + 1}/#{submission_ids.size}] Processing #{submission_id} with form #{form_key} (#{form_id})"

        config = SimpleFormsApi::FormRemediation::Configuration::Form0781Config.new(form_key:)
        job.perform(ids: [submission_id], config:, type: :remediation)

        results[:processed] << {
          submission_id:,
          form_key:,
          form_id:
        }
        puts "[#{idx + 1}/#{submission_ids.size}] Successfully processed: #{submission_id} (#{form_key})"
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

    # Emit DataDog metrics
    duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
    StatsD.gauge('tasks.simple_forms_api.remediate_0781_and_0781v2_forms.total', submission_ids.size)
    StatsD.gauge('tasks.simple_forms_api.remediate_0781_and_0781v2_forms.processed', results[:processed].size)
    StatsD.gauge('tasks.simple_forms_api.remediate_0781_and_0781v2_forms.skipped', results[:skipped].size)
    StatsD.gauge('tasks.simple_forms_api.remediate_0781_and_0781v2_forms.not_found', results[:not_found].size)
    StatsD.gauge('tasks.simple_forms_api.remediate_0781_and_0781v2_forms.errored', results[:errored].size)
    StatsD.measure('tasks.simple_forms_api.remediate_0781_and_0781v2_forms.duration', duration)

    Rails.logger.info('Task completed.')
  end
end
