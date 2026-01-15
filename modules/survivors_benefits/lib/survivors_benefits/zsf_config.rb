# frozen_string_literal: true

require 'simple_forms_api/form_remediation/configuration/base'

module SurvivorsBenefits
  # provides s3 settings to the PDF uploader
  class ZsfConfig < SimpleFormsApi::FormRemediation::Configuration::Base
    # the s3 settings
    def s3_settings
      Settings.bio.survivors_benefits
    end
  end
end
