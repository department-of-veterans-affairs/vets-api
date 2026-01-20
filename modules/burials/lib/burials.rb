# frozen_string_literal: true

require 'burials/engine'

##
# Burial 21P-530EZ Module
#
module Burials
  # The form_id
  FORM_ID = '21P-530EZ'

  # The module path
  MODULE_PATH = 'modules/burials'

  # Path to the PDF - conditionally use 2026 version
  def self.pdf_path
    if Flipper.enabled?(:burial_pdf_form_alignment)
      "#{MODULE_PATH}/lib/burials/pdf_fill/pdfs/#{FORM_ID}-V2.pdf"
    else
      "#{MODULE_PATH}/lib/burials/pdf_fill/pdfs/#{FORM_ID}.pdf"
    end
  end

  # Path to the PDF
  PDF_PATH = "#{MODULE_PATH}/lib/burials/pdf_fill/pdfs/#{FORM_ID}.pdf".freeze

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
