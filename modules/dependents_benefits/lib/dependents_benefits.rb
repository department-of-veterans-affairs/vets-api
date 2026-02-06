# frozen_string_literal: true

require 'dependents_benefits/engine'

##
# DependentsBenefits 686C-674 Module
#
module DependentsBenefits
  # The base claim form_id
  FORM_ID = '686C-674'
  # The versioned claim form_id
  FORM_ID_V2 = '686C-674-V2'
  # 21-686C Add/Remove Dependent form_id
  ADD_REMOVE_DEPENDENT = '21-686C'
  # 21-674 School Attendance Approval form_id
  SCHOOL_ATTENDANCE_APPROVAL = '21-674'
  # 21-509 Application for Parent Dependency form_id
  PARENT_DEPENDENCY = '21-509'

  # The module path
  MODULE_PATH = 'modules/dependents_benefits'

  # Path to the PDFs directory
  PDF_PATH_BASE = "#{MODULE_PATH}/lib/dependents_benefits/pdf_fill/pdfs".freeze
  # Path to the 21-686c PDF template
  PDF_PATH_21_686C = "#{PDF_PATH_BASE}/#{ADD_REMOVE_DEPENDENT}.pdf".freeze
  # Path to the 21-674 PDF template
  PDF_PATH_21_674 = "#{PDF_PATH_BASE}/#{SCHOOL_ATTENDANCE_APPROVAL}.pdf".freeze

  # path to the form schemas
  FORM_SCHEMA_BASE = "#{MODULE_PATH}/schema".freeze

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

  # Custom error class for missing veteran information in a claim
  # Usually caused by failing to add veteran info to the form data
  class MissingVeteranInfoError < StandardError; end

  # Exception raised when 674 claim validation fails
  class Invalid674Claim < StandardError; end

  # Exception raised when 686c claim validation fails
  class Invalid686cClaim < StandardError; end
end
