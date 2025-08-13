# frozen_string_literal: true

require 'dependents_verification/engine'

# The DependentsVerification module serves as a namespace for all classes, methods, and constants
# related to the Dependents Verification functionality. It encapsulates all logic relevant to
# handling dependents verification data.
module DependentsVerification
  # Income and Assets Form ID
  FORM_ID = '21-0538'

  # The module path
  MODULE_PATH = 'modules/dependents_verification'

  # Path to the PDF
  PDF_PATH = "#{DependentsVerification::MODULE_PATH}/lib/dependents_verification/pdf_fill/pdfs/#{FORM_ID}.pdf".freeze

  # API Version 0
  module V0
  end

  # PdfFill
  # @see lib/pdf_fill
  module PdfFill
  end

  # BenefitsIntake
  # @see lib/lighthouse/benefits_intake
  module BenefitsIntake
  end
end
