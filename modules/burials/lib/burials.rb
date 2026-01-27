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
    rescue => e
      # If flipper_gates table doesn't exist (e.g., during db:create), use default
      if e.is_a?(PG::UndefinedTable) || e.message.include?('flipper_gates')
        "#{MODULE_PATH}/lib/burials/pdf_fill/pdfs/#{FORM_ID}.pdf"
      else
        raise
      end
    end
  end

  def self.use_v2?
    begin
      Flipper.enabled?(:burial_pdf_form_alignment)
    rescue => e
      if e.is_a?(PG::UndefinedTable) || e.message.include?('flipper_gates')
        false
      else
        raise
      end
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
