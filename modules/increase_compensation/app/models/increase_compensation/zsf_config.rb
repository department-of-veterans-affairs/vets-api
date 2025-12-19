# frozen_string_literal: true

require 'simple_forms_api/form_remediation/configuration/base'

module IncreaseCompensation
  ##
  # IncreaseCompensation 21-8940v1 S3 Configuration

  class ZsfConfig < SimpleFormsApi::FormRemediation::Configuration::Base
    # provides s3 settings to the PDF uploader
    def s3_settings
      Settings.bio.increase_compensation
    end

    def handle_error(message, error, **details)
      log_error(message, error, **details)
      raise SimpleFormsApi::FormRemediation::Error.new(message:, error:)
    end
  end
end
