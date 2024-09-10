# frozen_string_literal: true

module SimpleFormsApi
  module S3Service
    module Jobs
      class SubmissionArchiveHandlerJob < SimpleFormsApi::S3Service::Utils
        include Sidekiq::Worker

        sidekiq_options retry: 3, queue: 'default'

        def perform(benefits_intake_uuids:, **options)
          defaults = default_options.merge(options)

          runner = SubmissionArchiveHandler.new(benefits_intake_uuids:, **defaults)
          result_dir = runner.run
          log_info("Job completed successfully. Results saved in directory: #{result_dir}")
        rescue => e
          handle_error('SubmissionArchiveHandlerJob failed.', e)
        end

        private

        def default_options
          {
            attachments: [],
            bundle_by_user: true,
            file_path: nil, # file path for the PDF file to be archived
            metadata: {}, # pertinent metadata for original file upload/submission
            parent_dir: 'vff-simple-forms', # S3 bucket base directory where files live
            signed_link: false # TODO: Will we ever need to make this optional?
          }
        end
      end
    end
  end
end
