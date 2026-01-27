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

  # Path to the PDF - conditionally toggle between V1 and V2 versions
  def self.pdf_path
    begin
      if Flipper.enabled?(:burial_pdf_form_alignment)
        "#{MODULE_PATH}/lib/burials/pdf_fill/pdfs/#{FORM_ID}-V2.pdf"
      else
        "#{MODULE_PATH}/lib/burials/pdf_fill/pdfs/#{FORM_ID}.pdf"
      end
    rescue StandardError => e
      # Default to V1 PDF path when database is not available or Flipper fails
      Rails.logger.debug("Burials.pdf_path: Error accessing Flipper (#{e.class}: #{e.message}), using default V1 PDF path")
      "#{MODULE_PATH}/lib/burials/pdf_fill/pdfs/#{FORM_ID}.pdf"
    end
  end

  def self.use_v2?
    begin
      Flipper.enabled?(:burial_pdf_form_alignment)
    rescue StandardError => e
      # Default to false when database is not available or Flipper fails
      Rails.logger.debug("Burials.use_v2?: Error accessing Flipper (#{e.class}: #{e.message}), defaulting to false")
      false
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
