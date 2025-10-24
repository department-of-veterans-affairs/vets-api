# frozen_string_literal: true

require 'increase_compensation/engine'

module IncreaseCompensation
  # APPLICATION FOR INCREASED COMPENSATION BASED ON UNEMPLOYABILITY Form ID
  FORM_ID = '21-8940V1'

  # The module path
  MODULE_PATH = 'modules/increase_compensation'

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
