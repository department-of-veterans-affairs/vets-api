# frozen_string_literal: true

module SimpleFormsApi
  module FormRemediation
    class Form526SubmissionArchive < SubmissionArchive
      def hydrate_submission_data
        raise "No #{config.id_type} was provided" unless id

        # Use create_remediation_data if available, otherwise fall back to default
        built_submission = if config.respond_to?(:create_remediation_data)
                             config.create_remediation_data(id:).hydrate!
                           else
                             config.remediation_data_class.new(id:, config:).hydrate!
                           end

        initialize_data(
          attachments: built_submission.attachments,
          file_path: built_submission.file_path,
          id: built_submission.submission.id,
          metadata: built_submission.metadata,
          submission: built_submission.submission,
          type: archive_type
        )
      end

      private

      def submission_file_name
        @submission_file_name ||= unique_file_name('526', id)
      end

      def manifest_entry
        [
          submission.created_at,
          '526',
          id
        ]
      end
    end
  end
end
