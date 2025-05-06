# frozen_string_literal: true

require 'forms/submission_statuses/pdf_urls'

module V0
  module MyVA
    class SubmissionPdfUrlsController < ApplicationController
      before_action :check_flipper_flag
      service_tag 'form-submission-pdf'

      def create
        url = Forms::SubmissionStatuses::PdfUrls.new(
          form_id: request_params[:form_id],
          submission_guid: request_params[:submission_guid]
        ).fetch_url

        raise Common::Exceptions::RecordNotFound, request_params[:submission_guid] unless url.is_a?(String)

        render json: { url: }
      end

      private

      def request_params
        params.require(%i[form_id submission_guid])
        params
      end

      def check_flipper_flag
        raise Common::Exceptions::Forbidden unless Flipper.enabled?(:my_va_form_submission_pdf_link,
                                                                    current_user)
      end
    end
  end
end
