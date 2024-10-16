# frozen_string_literal: true

require 'simple_forms_api/form_remediation/configuration/vff_config'
require_relative '../../app/services/simple_forms_api/form_remediation/jobs/archive_batch_processing_job'

# Invoke this as follows:
#  Passing just UUIDs (will use default type):
#    bundle exec rails simple_forms_api:archive_forms_by_uuid[abc-123 def-456]
#  Passing a custom type:
#    bundle exec rails simple_forms_api:archive_forms_by_uuid[abc-123 def-456,submission]
namespace :simple_forms_api do
  desc 'Kick off the ArchiveBatchProcessingJob to archive submissions to S3 and print presigned URLs'
  task :archive_forms_by_uuid, %i[benefits_intake_uuids type] => :environment do |_, args|
    benefits_intake_uuids = args[:benefits_intake_uuids].to_s.split(/[,\s]+/)
    type = args[:type] || :remediation

    begin
      validate_input!(benefits_intake_uuids)

      Rails.logger.info(
        "Starting ArchiveBatchProcessingJob for UUIDs: #{benefits_intake_uuids.join(', ')} using type: #{type}"
      )

      # Call the service object synchronously and get the presigned URLs
      config = SimpleFormsApi::FormRemediation::Configuration::VffConfig.new
      job = SimpleFormsApi::FormRemediation::Jobs::ArchiveBatchProcessingJob.new
      job.perform(ids: benefits_intake_uuids, config:, type: type.to_sym)

      Rails.logger.info('Task successfully completed.')
    rescue Common::Exceptions::ParameterMissing => e
      raise e
    rescue => e
      Rails.logger.error("Error occurred while archiving submissions: #{e.message}")
      puts 'An error occurred. Check logs for more details.'
    end
  end

  private

  def validate_input!(benefits_intake_uuids)
    raise Common::Exceptions::ParameterMissing, 'benefits_intake_uuids' unless benefits_intake_uuids&.any?
  end
end
