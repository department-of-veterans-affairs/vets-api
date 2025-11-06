# frozen_string_literal: true

require 'employment_questionnaires/engine'

module EmploymentQuestionnaires
  # Income and Assets Form ID
  FORM_ID = '21-4140'

  # The module path
  MODULE_PATH = 'modules/employment_questionnaires'

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
