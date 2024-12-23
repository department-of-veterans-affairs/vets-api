# frozen_string_literal: true

require 'simple_forms_api/form_remediation/configuration/vff_config'

module Forms
  module SubmissionStatuses
    class PdfUrls
      VFF_FORMS = %w[20-10206 20-10207 21-0845 21-0966 21-0972 21-10210 21-4138 21-4142 21P-0847 26-4555 40-0247
                     40-10007].freeze

      def initialize(form_id:, submission_guid:)
        @form_id = form_id
        @submission_guid = submission_guid
      end

      def fetch_url
        config = determine_config
        SimpleFormsApi::FormRemediation::S3Client.fetch_presigned_url(@submission_guid, config:)
      end

      def supported?
        determine_config
      rescue Common::Exceptions::Forbidden
        false
      else
        true
      end

      private

      def determine_config
        return SimpleFormsApi::FormRemediation::Configuration::VffConfig.new if VFF_FORMS.include?(@form_id)

        raise Common::Exceptions::Forbidden, detail: "Form '#{@form_id}' does not support pdf downloads"
      end
    end
  end
end
