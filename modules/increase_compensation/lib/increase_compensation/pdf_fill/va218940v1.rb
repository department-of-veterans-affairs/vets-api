# frozen_string_literal: true

require 'pdf_fill/forms/form_base'
require 'pdf_fill/forms/form_helper'
require 'pdf_fill/hash_converter'
require 'increase_compensation/constants'
require 'increase_compensation/helpers'
require 'increase_compensation/pdf_fill/sections/section_01'
require 'increase_compensation/pdf_fill/sections/section_02'
require 'increase_compensation/pdf_fill/sections/section_03'
require 'increase_compensation/pdf_fill/sections/section_04'
require 'increase_compensation/pdf_fill/sections/section_05'
require 'increase_compensation/pdf_fill/sections/section_06'

module IncreaseCompensation
  module PdfFill
    # The Va218940v1 Form
    class Va218940v1 < ::PdfFill::Forms::FormBase
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
      QUESTION_KEY = [
        # { question_number: '10', question_text: 'DATE(S) OF TREATMENT BY DOCTOR(S)' },
        # { question_number: '13', question_text: 'DATE(S) OF HOSPITALIZATION' },
        # { question_number: '21A', question_text: 'SCHOOLING AND OTHER TRAINING' },
        # { question_number: '24B', question_text: 'SCHOOLING AND OTHER TRAINING' },
        # { question_number: '25B', question_text: 'SCHOOLING AND OTHER TRAINING' }
        # { question_number: '26', question_text: 'REMARKS' }
      ].freeze

      # V2-style sections grouping question numbers for overflow pages
      SECTIONS = [
        { label: 'Section I: Veteran Identification Information', question_nums: %w[1 2 3 4 5 6 7] },
        { label: 'Section II: DISABILITY AND MEDICAL TREATMENT', question_nums: %w[8 9 10 11 12 13] },
        { label: 'Section III: EMPLOYMENT STATEMENT', question_nums: %w[14 15 16 17 18 19 20 21 22] },
        { label: 'Section IV: SCHOOLING AND OTHER TRAINING', question_nums: %w[23 24 25] },
        { label: 'Section V: REMARKS', question_nums: ['26'] },
        { label: 'Section VI: AUTHORIZATION, CERTIFICATION, AND SIGNATURE', question_nums: %w[27 28 29 30] }
      ].freeze

      # The list of section classes for form expansion and key building
      SECTION_CLASSES = [
        Section1, Section2, Section3, Section4, Section5, Section6
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
