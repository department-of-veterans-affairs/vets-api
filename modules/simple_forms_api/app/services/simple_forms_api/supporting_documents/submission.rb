# frozen_string_literal: true

require 'benefits_intake_service/service'

module SimpleFormsApi
  module SupportingDocuments
    class Submission
      FORMS_WITH_SUPPORTING_DOCUMENTS = %w[40-0247 20-10207 40-10007].freeze
      BENEFITS_INTAKE_VALIDATION_FORMS = %w[40-0247 40-10007].freeze

      def initialize(current_user, params)
        @current_user = current_user
        @params = params.deep_symbolize_keys
      end

      def submit
        attachment = build_attachment
        validate_document(params[:file].tempfile.path)

        attachment.save
        PersistentAttachmentSerializer.new(attachment)
      rescue BenefitsIntakeService::Service::InvalidDocumentError => e
        { error: "Document validation failed: #{e.message}" }
      end

      private

      attr_reader :current_user, :params

      def build_attachment
        PersistentAttachments::MilitaryRecords.new(form_id: params[:form_id]).tap do |attachment|
          attachment.file = params[:file]
        end
      end

      def validate_document(file_path)
        Tempfile.open(['upload', File.extname(file_path)]) do |tempfile|
          tempfile.write(File.read(file_path))
          tempfile.rewind

          if BENEFITS_INTAKE_VALIDATION_FORMS.include?(params[:form_id])
            validate_with_benefits_intake(tempfile.path)
          else
            attachment = PersistentAttachments::MilitaryRecords.new(form_id: params[:form_id], file: tempfile)
            raise Common::Exceptions::ValidationErrors, attachment unless attachment.valid?
          end
        end
      end

      def validate_with_benefits_intake(file_path)
        BenefitsIntakeService::Service.new.valid_document?(document: file_path)
      end
    end
  end
end
