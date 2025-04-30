# frozen_string_literal: true

require 'simple_forms_api/form_remediation/configuration/base'

module SimpleFormsApi
  module FormRemediation
    module Configuration
      class Form0781Config < Base
        attr_reader :form_key, :form_id

        def initialize(form_key: 'form0781a', form_id: nil)
          super()
          @form_key = form_key
          @form_id = form_id
        end

        def submission_archive_class
          SimpleFormsApi::FormRemediation::Form526SubmissionArchive
        end

        def remediation_data_class
          SimpleFormsApi::FormRemediation::Form0781SubmissionRemediationData
        end

        def create_remediation_data(id:)
          remediation_data_class.new(id:, config: self, form_key:, form_id:)
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
