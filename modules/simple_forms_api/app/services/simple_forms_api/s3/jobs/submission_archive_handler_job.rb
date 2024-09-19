# frozen_string_literal: true

module SimpleFormsApi
  module S3
    module Jobs
      class SubmissionArchiveHandlerJob < SimpleFormsApi::S3::Utils
        include Sidekiq::Worker

        sidekiq_options retry: 3, queue: 'default'

        def perform(benefits_intake_uuids: [], parent_dir: 'vff-simple-forms')
          @presigned_urls = []
          runner = SubmissionArchiveHandler.new(benefits_intake_uuids:, parent_dir:)
          @presigned_urls = runner.upload
          log_info('SubmissionArchiveHandlerJob completed successfully.')
        rescue => e
          handle_error('SubmissionArchiveHandlerJob failed.', e)
        end

        private

        attr_reader :presigned_urls
      end
    end
  end
end
