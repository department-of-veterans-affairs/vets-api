# frozen_string_literal: true

require 'simple_forms_api/form_remediation/configuration/base'

module SimpleFormsApi
  module FormRemediation
    module Configuration
      class Form0781Config < Base
        def submission_archive_class
          SimpleFormsApi::FormRemediation::Form526SubmissionArchive
        end

        def remediation_data_class
          SimpleFormsApi::FormRemediation::Form0781SubmissionRemediationData
        end

        def temp_directory_path
          Rails.root.join("tmp/#{SecureRandom.hex}-archive").to_s
        end

        def s3_settings
          Settings.form0781_remediation.aws
        end
      end
    end
  end
end
