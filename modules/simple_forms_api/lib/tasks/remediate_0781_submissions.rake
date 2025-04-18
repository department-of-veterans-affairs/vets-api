# frozen_string_literal: true

require 'simple_forms_api/form_remediation/configuration/form_0781_config'
require_relative '../../app/services/simple_forms_api/form_remediation/jobs/archive_batch_processing_job'

# Invoke this as follows:
#  Passing just form526_submission_ids (will use default type):
#    bundle exec rails simple_forms_api:remediate_0781_submissions[123 456]

def validate_input!(form526_submission_ids)
  raise Common::Exceptions::ParameterMissing, 'form526_submission_ids' unless form526_submission_ids&.any?
end

namespace :simple_forms_api do
  desc 'Kick off the ArchiveBatchProcessingJob to archive 0781 submissions to S3 and print presigned URLs'
  task :remediate_0781_submissions, %i[form526_submission_ids] => :environment do |_, args|
    form526_submission_ids = args[:form526_submission_ids].to_s.split(/[,\s]+/)
    type = :remediation

    begin
      validate_input!(form526_submission_ids)

      Rails.logger.info(
        "Starting ArchiveBatchProcessingJob for form 526 ids: #{form526_submission_ids.join(', ')} using type: #{type}"
      )

      # Call the service object synchronously and get the presigned URLs
      config = SimpleFormsApi::FormRemediation::Configuration::Form0781Config.new
      job = SimpleFormsApi::FormRemediation::Jobs::ArchiveBatchProcessingJob.new
      job.perform(ids: form526_submission_ids, config:, type: type.to_sym)

      Rails.logger.info('Task successfully completed.')
    rescue Common::Exceptions::ParameterMissing => e
      raise e
    rescue => e
      Rails.logger.error("Error occurred while archiving submissions: #{e.message}")
      puts 'An error occurred. Check logs for more details.'
    end
  end
end
