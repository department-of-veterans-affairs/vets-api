# frozen_string_literal: true

module SimpleFormsApi
  module S3Service
    class SubmissionArchiveHandlerJob < Utils
      include Sidekiq::Worker

      sidekiq_options retry: 3, queue: 'default'

      def perform(submission_ids:, **options)
        defaults = default_options.merge(options)

        runner = SubmissionArchiveHandler.new(submission_ids:, **defaults)
        result_dir = runner.run
        log_info("Job completed successfully. Results saved in directory: #{result_dir}")
      rescue => e
        handle_job_error(e)
      end

      private

      def default_options
        {
          bundle_by_user: true,
          file_path: nil, # file path for the PDF file to be archived
          metadata: nil,
          parent_dir: 'vff-simple-forms',
          quiet_pdf_failures: false,
          quiet_upload_failures: false,
          run_quiet: true,
          signed_link: false
        }
      end

      def handle_job_error(error)
        log_error('SubmissionArchiveHandlerJob failed.', error)
        raise error
      end
    end
  end
end
