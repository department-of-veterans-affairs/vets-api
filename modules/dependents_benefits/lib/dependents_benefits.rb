# frozen_string_literal: true

require 'dependents_benefits/engine'

##
# DependentsBenefits 686C-674 Module
#
module DependentsBenefits
  # The form_id
  FORM_ID = '686C-674'
  FORM_ID_V2 = '686C-674-V2'
  ADD_REMOVE_DEPENDENT = '21-686C'
  SCHOOL_ATTENDANCE_APPROVAL = '21-674'
  PARENT_DEPENDENCY = '21-509'

  # The module path
  MODULE_PATH = 'modules/dependents_benefits'

  # Path to the PDF
  PDF_PATH_BASE = "#{MODULE_PATH}/lib/dependents_benefits/pdf_fill/pdfs".freeze
  PDF_PATH_21_686C = "#{PDF_PATH_BASE}/#{ADD_REMOVE_DEPENDENT}.pdf".freeze
  PDF_PATH_21_674 = "#{PDF_PATH_BASE}/#{SCHOOL_ATTENDANCE_APPROVAL}.pdf".freeze

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
