# frozen_string_literal: true

require 'simple_forms_api/form_remediation/configuration/base'

module MedicalExpenseReports
  # provides s3 settings to the PDF uploader
  class ZsfConfig < SimpleFormsApi::FormRemediation::Configuration::Base
    # the s3 settings
    def s3_settings
      Settings.bio.medical_expense_reports
    end
  end
end
