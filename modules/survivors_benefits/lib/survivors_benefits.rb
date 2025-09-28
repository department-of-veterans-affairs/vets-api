# frozen_string_literal: true

require 'survivors_benefits/engine'

module SurvivorsBenefits
  # Income and Assets Form ID
  FORM_ID = '21P-534EZ'

  # The module path
  MODULE_PATH = 'modules/survivors_benefits'

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
