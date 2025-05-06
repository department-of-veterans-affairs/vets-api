# frozen_string_literal: true

require 'simple_forms_api/form_remediation/configuration/base'

module SimpleFormsApi
  module FormRemediation
    module Configuration
      class Form0781Config < Base
        attr_reader :form_key, :form_id

        def initialize(form_key: 'form0781a')
          super()
          raise ArgumentError, "Unknown form_key: #{form_key}" unless self.class.form_key_to_id.key?(form_key)

          @form_key = form_key
          @form_id  = self.class.form_key_to_id[form_key]
        end

        # Class method to access mapping - loads dependency before accessing constants
        def self.form_key_to_id
          # Only require when this method is called, not when the file is loaded
          require 'evss/disability_compensation_form/submit_form0781'

          {
            'form0781' => EVSS::DisabilityCompensationForm::SubmitForm0781::FORM_ID_0781,
            'form0781a' => EVSS::DisabilityCompensationForm::SubmitForm0781::FORM_ID_0781A,
            'form0781v2' => EVSS::DisabilityCompensationForm::SubmitForm0781::FORM_ID_0781V2
          }.freeze
        end

        def submission_archive_class
          SimpleFormsApi::FormRemediation::Form526SubmissionArchive
        end

        def remediation_data_class
          SimpleFormsApi::FormRemediation::Form0781SubmissionRemediationData
        end

        def create_remediation_data(id:)
          remediation_data_class.new(id:, config: self, form_key:)
        end

        def s3_settings
          Settings.form0781_remediation.aws
        end
      end
    end
  end
end
