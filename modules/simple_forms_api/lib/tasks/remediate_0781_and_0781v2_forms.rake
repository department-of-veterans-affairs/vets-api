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

# Context object to reduce parameter count
ProcessingContext = Struct.new(:job, :results, :submission_id, :form_key, :form_id, :idx, :total_size,
                               keyword_init: true)

def validate_input!(ids)
  raise Common::Exceptions::ParameterMissing, 'submission_ids' unless ids&.any?
end

def log_processing_step(context, step)
  templates = {
    skipped: '[%<current>d/%<total>d] Skipped: %<id>s (%<form>s) - blank form content',
    processing: '[%<current>d/%<total>d] Processing %<id>s with form %<form>s (%<form_id>s)',
    success: '[%<current>d/%<total>d] Successfully processed: %<id>s (%<form>s)'
  }

  message = format(
    templates[step],
    current: context.idx + 1,
    total: context.total_size,
    id: context.submission_id,
    form: context.form_key,
    form_id: context.form_id
  )
  puts message
end

def handle_blank_form!(form_content, context)
  return false if form_content.present?

  context.results[:skipped] << { submission_id: context.submission_id, form_key: context.form_key,
                                 reason: 'blank_form_content' }
  log_processing_step(context, :skipped)
  true
end

def process_form!(context)
  log_processing_step(context, :processing)

  config = SimpleFormsApi::FormRemediation::Configuration::Form0781Config.new(form_key: context.form_key)
  context.job.perform(ids: [context.submission_id], config:, type: :remediation)
  context.results[:processed] << { submission_id: context.submission_id, form_key: context.form_key,
                                   form_id: context.form_id }

  log_processing_step(context, :success)
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

      if created_at < Date.new(2019, 6, 24)
        # Pre-2019-06-24 submissions: form_key is implicitly 'form0781'
        form_id = EVSS::DisabilityCompensationForm::SubmitForm0781::FORM_ID_0781
        form_content = JSON.parse(submission.form_to_json(Form526Submission::FORM_0781))

        context = ProcessingContext.new(
          job:,
          results:,
          submission_id:,
          form_key: 'form0781',
          form_id:,
          idx:,
          total_size: submission_ids.size
        )

        next if handle_blank_form!(form_content, context)

        process_form!(context)
      else
        # Post-2019-06-24 submissions: multiple form types
        nested_json = JSON.parse(submission.form_to_json(Form526Submission::FORM_0781))
        {
          'form0781' => EVSS::DisabilityCompensationForm::SubmitForm0781::FORM_ID_0781,
          'form0781v2' => EVSS::DisabilityCompensationForm::SubmitForm0781::FORM_ID_0781V2
          # 'form0781a' => EVSS::DisabilityCompensationForm::SubmitForm0781::FORM_ID_0781A,
          # Already processed in modules/simple_forms_api/lib/tasks/remediate_0781a_forms.rake
        }.each do |form_key, form_id|
          form_content = nested_json[form_key]
          context = ProcessingContext.new(
            job:,
            results:,
            submission_id:,
            form_key:,
            form_id:,
            idx:,
            total_size: submission_ids.size
          )

          next if handle_blank_form!(form_content, context)

          process_form!(context)
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
