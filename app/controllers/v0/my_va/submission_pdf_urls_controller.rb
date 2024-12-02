# frozen_string_literal: true

require 'simple_forms_api/form_remediation/configuration/vff_config'

module V0
  module MyVA
    class SubmissionPdfUrlsController < ApplicationController
      service_tag 'form-submission-pdf-urls'

      VFF_FORMS = %w[20-10206 20-10207 21-0845 21-0966 21-0972 21-10210
                     21-4138 21-4142 21P-0847 26-4555 40-0247 40-10007].freeze

      def create
        config = get_config(request_params[:form_id])
        guid = request_params[:submission_guid]
        url = SimpleFormsApi::FormRemediation::S3Client.fetch_presigned_url(guid, config:)

        raise Common::Exceptions::RecordNotFound, guid unless url.is_a? String

        render json: {
          url: url
        }
      end

      private

      def get_config(form_id)
        if VFF_FORMS.include?(form_id)
          SimpleFormsApi::FormRemediation::Configuration::VffConfig.new
        else
          raise Common::Exceptions::Forbidden,
                detail: "Form '#{form_id}' does not support pdf downloads"
        end
      end

      def request_params
        params.require(%i[form_id submission_guid])
        params.permit(
          :form_id,
          :submission_guid
        )
      end
    end
  end
end
