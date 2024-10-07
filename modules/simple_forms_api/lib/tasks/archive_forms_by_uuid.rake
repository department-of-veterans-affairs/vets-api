# frozen_string_literal: true

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
      presigned_urls = SimpleFormsApi::FormRemediation::ArchiveBatchProcessingJob.perform(
        ids: benefits_intake_uuids, config:, type: type.to_sym
      )

      Rails.logger.info('ArchiveBatchProcessingJob completed successfully.')

      # ArgoCD makes it impossible to download any files so
      # the URLs must be printed to the console.
      handle_presigned_urls(presigned_urls)

      Rails.logger.info('Task successfully completed.')
    rescue => e
      Rails.logger.error("Error occurred while archiving submissions: #{e.message}")
      puts 'An error occurred. Check logs for more details.'
    end
  end

  private

  def validate_input!(benefits_intake_uuids)
    raise 'Error: No benefits_intake_uuids provided.' if benefits_intake_uuids.blank?
  end

  # This redundancy ensures we have a way to retrieve the URLs
  # easily if ArgoCD crashes or times out.
  def handle_presigned_urls(presigned_urls)
    if presigned_urls.present?
      Rails.logger.info("Generated presigned URLs: #{presigned_urls.join(', ')}")
      puts 'Presigned URLs:'
      presigned_urls.each { |url| puts url }
    else
      Rails.logger.warn('No URLs were generated.')
      puts 'No URLs were generated.'
      raise 'Presigned URLs were not generated' unless presigned_urls
    end
  end
end
