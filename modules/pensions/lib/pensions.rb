# frozen_string_literal: true

require 'pensions/engine'

##
# Pension 21P-527EZ Module
#
module Pensions
  # The form_id
  FORM_ID = '21P-527EZ'

  # The module path
  MODULE_PATH = 'modules/pensions'

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

  # ZeroSilentFailures
  # @see lib/zero_silent_failures
  module ZeroSilentFailures
  end
end
