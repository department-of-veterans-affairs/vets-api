# frozen_string_literal: true

module VRE
  module V0
    class CaseGetDocumentController < ApplicationController
      service_tag 'vre-application'

      def create
        validate_required_params!

        env = case_get_document_service.get_document(document_params)
        content_type = pdf_content_type(env)
        send_data env.body,
                  type: content_type,
                  disposition: 'inline'
      end

      private

      def case_get_document_service
        VRE::CaseGetDocument::Service.new(@current_user&.icn)
      end

      def document_params
        params.permit(:resCaseId, :documentType)
      end

      def validate_required_params!
        raise Common::Exceptions::ParameterMissing, 'resCaseId' if document_params[:resCaseId].blank?
        raise Common::Exceptions::ParameterMissing, 'documentType' if document_params[:documentType].blank?
      end

      def pdf_content_type(env)
        env.response_headers['content-type']&.split(';')&.first || 'application/pdf'
      end
    end
  end
end
