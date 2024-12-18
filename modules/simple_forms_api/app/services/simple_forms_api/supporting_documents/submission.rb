# frozen_string_literal: true

module SimpleFormsApi
  module SupportingDocuments
    class Submission
      FORMS_WITH_SUPPORTING_DOCUMENTS = %w[40-0247 20-10207 40-10007].freeze

      def initialize(current_user, params)
        @current_user = current_user
        @params = params
      end

      def submit
        attachment = PersistentAttachments::MilitaryRecords.new(form_id: params[:form_id])
        attachment.file = params['file']
        file_path = params['file'].tempfile.path
        # Validate the document using BenefitsIntakeService
        if %w[40-0247 40-10007].include?(params[:form_id])
          begin
            service = BenefitsIntakeService::Service.new
            service.valid_document?(document: file_path)
          rescue BenefitsIntakeService::Service::InvalidDocumentError => e
            render json: { error: "Document validation failed: #{e.message}" }, status: :unprocessable_entity
            return
          end
        end
        raise Common::Exceptions::ValidationErrors, attachment unless attachment.valid?

        attachment.save
        render json: PersistentAttachmentSerializer.new(attachment)
      end
    end
  end
end
