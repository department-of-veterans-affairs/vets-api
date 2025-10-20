# frozen_string_literal: true

require 'pdf_fill/forms/form_base'
require 'pdf_fill/forms/form_helper'
require 'pdf_fill/hash_converter'
require 'increase_compensation/constants'
require 'increase_compensation/helpers'

module IncreaseCompensation
  module PdfFill
    # The Va218940 Form
    class Va218940 < ::PdfFill::Forms::FormBase
      include ::PdfFill::Forms::FormHelper
      include IncreaseCompensation::Helpers

      # The Form ID
      FORM_ID = IncreaseCompensation::FORM_ID

      # Hash iterator
      ITERATOR = ::PdfFill::HashConverter::ITERATOR

      # The path to the PDF template for the form
      TEMPLATE = "#{IncreaseCompensation::MODULE_PATH}/lib/increase_compensation/pdf_fill/pdfs/#{FORM_ID}.pdf".freeze

      # Starting page number for overflow pages
      START_PAGE = 5

      # Map question numbers to descriptive titles for overflow attachments
      QUESTION_KEY = [].freeze

      # V2-style sections grouping question numbers for overflow pages
      SECTIONS = [].freeze

      # The list of section classes for form expansion and key building
      SECTION_CLASSES = [
        # Section1, Section2, Section3, Section4, Section5, Section6
      ].freeze

      key = {}

      SECTION_CLASSES.each { |section| key.merge!(section::KEY) }

      # Form configuration hash
      KEY = key.freeze

      # Default label column width (points) for redesigned extras in this form
      DEFAULT_LABEL_WIDTH = 130

      # Post-process form data to match the expected format.
      # Each section of the form is processed in its own expand function.
      #
      # @param _options [Hash] any options needed for post-processing
      #
      # @return [Hash] the processed form data
      #
      def merge_fields(_options = {})
        SECTION_CLASSES.each { |section| section.new.expand(form_data) }

        form_data
      end
    end
  end
end
