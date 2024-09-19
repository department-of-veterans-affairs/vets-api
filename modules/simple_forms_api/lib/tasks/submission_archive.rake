# frozen_string_literal: true

# rake submission_archive:archive BENEFITS_INTAKE_UUIDS=uuid1,uuid2,uuid3 PARENT_DIR=my_custom_directory
namespace :simple_forms_api do
  namespace :submission_archive do
    desc 'Kick off the SubmissionArchiveHandlerJob to archive submissions to S3 and print presigned URLs'
    task :archive, %i[benefits_intake_uuids download_path] => :environment do |_, args|
      benefits_intake_uuids = args[:benefits_intake_uuids].split(',')
      parent_dir = args[:parent_dir] || 'vff-simple-forms'

      if benefits_intake_uuids.any?
        # Run the job synchronously and get the presigned URLs
        job_instance = SimpleFormsApi::S3::Jobs::SubmissionArchiveHandlerJob.new
        presigned_urls = job_instance.perform(benefits_intake_uuids:, parent_dir:)

        # ArgoCD makes it impossible to download any files so
        # the urls must be printed to console.
        if presigned_urls.present?
          puts 'Presigned URLs:'
          presigned_urls.each { |url| puts url }
        else
          puts 'No URLs were generated.'
        end
      else
        puts 'Error: No benefits_intake_uuids provided. Please provide them as a comma-separated parameter.'
      end
    end
  end
end
