# frozen_string_literal: true

require 'medical_expense_reports/engine'

module MedicalExpenseReports
  # Income and Assets Form ID
  FORM_ID = '21P-8416'

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
