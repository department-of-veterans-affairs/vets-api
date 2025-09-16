# frozen_string_literal: true

require 'dependents_benefits/engine'

##
# DependentsBenefits 686C-674 Module
#
module DependentsBenefits
  # The form_id
  FORM_ID = '686C-674'

  # The module path
  MODULE_PATH = 'modules/dependents_benefits'

  # Path to the PDF
  PDF_PATH = "#{MODULE_PATH}/lib/dependents_benefits/pdf_fill/pdfs/#{FORM_ID}.pdf".freeze

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
