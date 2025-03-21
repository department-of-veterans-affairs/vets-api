# frozen_string_literal: true

require 'simple_forms_api/form_remediation/configuration/base'

module SimpleFormsApi
  module FormRemediation
    module Configuration
      class Form0781Config < Base
        def submission_type
          Form526Submission
        end

        def remediation_data_class
          SimpleFormsApi::FormRemediation::Form526SubmissionRemediationData
        end

        def s3_settings
          # TODO: Replace the below with the actual settings
          # Settings.vff_simple_forms.aws
        end
      end
    end
  end
end
