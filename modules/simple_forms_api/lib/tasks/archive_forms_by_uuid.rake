# frozen_string_literal: true

# Invoke this as follows:
#  Set the parameters as variables ahead of time:
#    rails simple_forms_api:archive_forms_by_uuid[benefits_intake_uuids, parent_dir]
#  Pass in UUIDs only if default parent_dir is appropriate:
#    rails simple_forms_api:archive_forms_by_uuid[abc-123 def-456]
# Pass in new directory to override default:
#    rails simple_forms_api:archive_forms_by_uuid[abc-123 def-456,custom-directory]
namespace :simple_forms_api do
  desc 'Kick off the SubmissionArchiveHandlerJob to archive submissions to S3 and print presigned URLs'
  task :archive_forms_by_uuid, %i[benefits_intake_uuids parent_dir] => :environment do |_, args|
    benefits_intake_uuids = args[:benefits_intake_uuids]&.split || []
    parent_dir = args[:parent_dir] || 'vff-simple-forms'

    begin
      validate_input!(benefits_intake_uuids)

      Rails.logger.info("Starting SubmissionArchiveHandlerJob for UUIDs: #{benefits_intake_uuids.join(', ')}")

      # Run the job synchronously and get the presigned URLs
      job_instance = SimpleFormsApi::S3::Jobs::SubmissionArchiveHandlerJob.new
      presigned_urls = job_instance.perform(benefits_intake_uuids:, parent_dir:)

      # ArgoCD makes it impossible to download any files so
      # the urls must be printed to console.
      handle_presigned_urls(presigned_urls)

      Rails.logger.info('SubmissionArchiveHandlerJob completed successfully.')
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
    end
  end
end
