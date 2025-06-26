# frozen_string_literal: true

require 'pdf_fill/forms/form_base'
require 'pdf_fill/forms/form_helper'
require 'pdf_fill/hash_converter'
require 'dependents_verification/pdf_fill/sections/section1'
require 'dependents_verification/pdf_fill/sections/section2'

module DependentsVerification
  module PdfFill
    # The Va21p0969 Form
    class Va210538 < ::PdfFill::Forms::FormBase
      include ::PdfFill::Forms::FormHelper

      # The Form ID
      FORM_ID = DependentsVerification::FORM_ID

      # Hash iterator
      ITERATOR = ::PdfFill::HashConverter::ITERATOR

      # The path to the PDF template for the form
      TEMPLATE = DependentsVerification::PDF_PATH

      # The list of section classes for form expansion and key building
      SECTION_CLASSES = [Section1, Section2].freeze

      key = {}

      SECTION_CLASSES.each { |section| key.merge!(section::KEY) }

      # Form configuration hash
      KEY = key.freeze

      # Post-process form data to match the expected format.
      # Each section of the form is processed in its own expand function.
      #
      # @param _options [Hash] any options needed for post-processing
      #
      # @return [Hash] the processed form data
      #
      def merge_fields(_options = {})
        SECTION_CLASSES.each { |section| section.new.expand(form_data) }

        # Remove the dependencyVerification key from the form data
        # as it is not needed in the final output
        form_data.delete('dependencyVerification')

        form_data
      end
    end
  end
end
