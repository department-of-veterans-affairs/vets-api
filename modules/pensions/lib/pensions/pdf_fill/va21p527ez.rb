# frozen_string_literal: true

require 'pdf_fill/forms/form_base'

require_relative 'constants'

# Sections
require_relative 'sections/section_01'
require_relative 'sections/section_02'
require_relative 'sections/section_03'
require_relative 'sections/section_04'
require_relative 'sections/section_05'
require_relative 'sections/section_06'
require_relative 'sections/section_07'
require_relative 'sections/section_08'
require_relative 'sections/section_09'
require_relative 'sections/section_10'
require_relative 'sections/section_11'
require_relative 'sections/section_12'

module Pensions
  module PdfFill
    # The Va21p527ez Form
    class Va21p527ez < ::PdfFill::Forms::FormBase
      # The Form ID
      FORM_ID = Pensions::FORM_ID

      # The PDF Template
      TEMPLATE = "#{Pensions::MODULE_PATH}/lib/pensions/pdf_fill/pdfs/21P-527EZ.pdf".freeze

      # Starting page number for overflow pages
      START_PAGE = 16

      # Default label column width (points) for redesigned extras in this form
      DEFAULT_LABEL_WIDTH = 130

      # Map question numbers to descriptive titles for overflow attachments
      QUESTION_KEY = [
        { question_number: '1', question_text: "Veteran's Identification Information" },
        { question_number: '2', question_text: "Veteran's Contact Information" },
        { question_number: '3', question_text: "Veteran's Service Information" },
        { question_number: '4', question_text: 'VA Medical Centers' },
        { question_number: '4g', question_text: 'Federal Medical Facilities' },
        { question_number: '5', question_text: 'Employment History' },
        { question_number: '6', question_text: 'Marital Status' },
        { question_number: '7', question_text: 'Prior Marital History' },
        { question_number: '7b', question_text: 'Prior Spouse Marital History' },
        { question_number: '8', question_text: 'Dependent Children' },
        { question_number: '9', question_text: 'Income and Assets' },
        { question_number: '10', question_text: 'Care Expenses' },
        { question_number: '10b', question_text: 'Medical Expenses' },
        { question_number: '11', question_text: 'Direct Deposit Information' },
        { question_number: '12', question_text: 'Claim Certification and Signature' }
      ].freeze

      # V2-style sections grouping question numbers for overflow pages
      SECTIONS = [
        { label: 'Section I: Veteran\'s Identification Information', question_nums: ['1'] },
        { label: 'Section II: Veteran\'s Contact Information', question_nums: ['2'] },
        { label: 'Section III: Veteran\'s Service Information', question_nums: ['3'] },
        { label: 'Section IV: Pension Information', question_nums: ['4'] },
        { label: 'Section V: Employment History', question_nums: ['5'] },
        { label: 'Section VI: Marital Status', question_nums: ['6'] },
        { label: 'Section VII: Prior Marital History', question_nums: ['7'] },
        { label: 'Section VIII: Dependent Children', question_nums: ['8'] },
        { label: 'Section IX: Income and Assets', question_nums: ['9'] },
        { label: 'Section X: Care/Medical Expenses', question_nums: ['10'] },
        { label: 'Section XI: Direct Deposit Information', question_nums: ['11'] },
        { label: 'Section XII: Claim Certification and Signature', question_nums: ['12'] }
      ].freeze

      # The list of section classes for form expansion and key building
      SECTION_CLASSES = [
        Section1, Section2, Section3, Section4, Section5, Section6,
        Section7, Section8, Section9, Section10, Section11, Section12
      ].freeze

      # Build the full key by merging in section keys
      key = {}

      # Build up key hash for Sections 1-12
      SECTION_CLASSES.each { |section| key = key.merge(section::KEY) }

      # form configuration hash
      KEY = key.freeze

      ###
      # Merge all the key data together
      #
      def merge_fields(_options = {})
        SECTION_CLASSES.each { |section| section.new.expand(@form_data) }

        @form_data
      end
    end
  end
end
