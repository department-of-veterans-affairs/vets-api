# frozen_string_literal: true

module SimpleFormsApi
  module Dev
    # Helper class to stub external dependencies for remediation tasks in development.
    # This allows running the remediation tasks locally without AWS or PDF dependencies.
    #
    # Usage:
    # 1. Ensure you have a Form526Submission in your local database:
    #    - Your local seeds should include Form526Submission.find(1)
    #    - Or create one manually in rails console
    #
    # 2. Run the remediation task:
    #    bundle exec rails "simple_forms_api:remediate_0781_and_0781v2_forms[1]"
    #
    # The stubs will:
    # - Return mock responses for AWS S3 operations
    # - Use a dummy PDF file instead of generating real PDFs
    # - Skip actual PDF stamping
    # - Return mock URLs for archive operations
    class RemediationStubs
      def self.apply
        require 'fileutils'
        # Stub AWS S3 calls
        Aws.config.update(stub_responses: true) if defined?(Aws)

        # Prepare dummy PDF file
        dummy_pdf = Rails.root.join('tmp', 'mock.pdf')
        FileUtils.mkdir_p(File.dirname(dummy_pdf))
        FileUtils.touch(dummy_pdf) unless File.exist?(dummy_pdf)

        # Stub fill_ancillary_form to return dummy PDF
        PdfFill::Filler.singleton_class.prepend(Module.new do
          define_method(:fill_ancillary_form) { |*| dummy_pdf.to_s }
        end)

        # Stub PdfStamper to no-op
        SimpleFormsApi::PdfStamper.class_eval do
          def stamp_pdf
            Rails.logger.info("DEV stub: skip stamping for #{stamped_template_path}")
            stamped_template_path
          end
        end

        # Stub ArchiveBatchProcessingJob#archive_submission to skip zipping and upload
        SimpleFormsApi::FormRemediation::Jobs::ArchiveBatchProcessingJob.class_eval do
          def archive_submission(id)
            Rails.logger.info("DEV stub: skip archiving for #{id}")
            "https://example.com/mock_#{id}.zip"
          end
        end
      end
    end
  end
end
