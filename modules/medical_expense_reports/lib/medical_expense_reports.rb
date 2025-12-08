# frozen_string_literal: true

require 'medical_expense_reports/engine'

# Medical Expense Reports 21P-8416
# report medical or dental expenses that you have paid for yourself or for a family member living in your household
module MedicalExpenseReports
  # Income and Assets Form ID
  FORM_ID = '21P-8416'
  FORM_VERSION = 'OCT 2023'
  FORM_TYPE_LABEL = "VA FORM #{FORM_ID}, #{FORM_VERSION}"

  # The module path
  MODULE_PATH = 'modules/medical_expense_reports'

  # API Version 0
  module V0
  end

  # BenefitsIntake
  # @see lib/lighthouse/benefits_intake
  module BenefitsIntake
  end

  # PdfFill
  # @see lib/pdf_fill
  module PdfFill
  end
end
