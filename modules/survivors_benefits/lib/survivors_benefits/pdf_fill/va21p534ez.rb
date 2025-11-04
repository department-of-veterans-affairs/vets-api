# frozen_string_literal: true

require 'pdf_fill/forms/form_base'
require 'pdf_fill/forms/form_helper'
require 'pdf_fill/hash_converter'
require 'survivors_benefits/constants'
require 'survivors_benefits/helpers'
require 'survivors_benefits/pdf_fill/sections/section_01'
require 'survivors_benefits/pdf_fill/sections/section_02'
require 'survivors_benefits/pdf_fill/sections/section_03'
require 'survivors_benefits/pdf_fill/sections/section_04'
require 'survivors_benefits/pdf_fill/sections/section_05'
require 'survivors_benefits/pdf_fill/sections/section_06'
require 'survivors_benefits/pdf_fill/sections/section_07'
require 'survivors_benefits/pdf_fill/sections/section_08'
require 'survivors_benefits/pdf_fill/sections/section_09'
require 'survivors_benefits/pdf_fill/sections/section_10'
require 'survivors_benefits/pdf_fill/sections/section_11'
require 'survivors_benefits/pdf_fill/sections/section_12'

module SurvivorsBenefits
  module PdfFill
    # The Va21p8416 Form
    class Va21p534ez < ::PdfFill::Forms::FormBase
      include ::PdfFill::Forms::FormHelper
      include SurvivorsBenefits::Helpers

      # The Form ID
      FORM_ID = SurvivorsBenefits::FORM_ID

      # Hash iterator
      ITERATOR = ::PdfFill::HashConverter::ITERATOR

      # The path to the PDF template for the form
      TEMPLATE = "#{SurvivorsBenefits::MODULE_PATH}/lib/survivors_benefits/pdf_fill/pdfs/#{FORM_ID}.pdf".freeze

      # Starting page number for overflow pages
      START_PAGE = 11

      # Map question numbers to descriptive titles for overflow attachments
      QUESTION_KEY = [
        { question_number: '1', question_text: "Veteran's Identification Information" },
        { question_number: '2', question_text: "Claimant's Contact Information" },
        { question_number: '3', question_text: 'Reporting Period' },
        { question_number: '4', question_text: 'In-Home Care And Care Facility Expenses' },
        { question_number: '5', question_text: 'Other Medical Expenses' },
        { question_number: '6', question_text: 'Mileage' },
        { question_number: '7', question_text: 'Certification And Signature' },
        { question_number: '8', question_text: 'Witness To Signature' },
        { question_number: '9', question_text: 'In-Home Care Or Care Facility Expenses' },
        { question_number: '10', question_text: 'Other Medical Expenses' },
        { question_number: '11', question_text: 'Mileage For Privately Owned Vehicle Travel For Medical Expenses' },
        { question_number: '12', question_text: 'For A Residential Care, Adult Daycare, Or A Similar Facility' },
        { question_number: '13', question_text: 'For In-Home Attendant Expenses' }
      ].freeze

      # V2-style sections grouping question numbers for overflow pages
      SECTIONS = [
        { label: 'Section I: Veteran\'s Identification Information', question_nums: ['1'] },
        { label: 'Section II: Claimant\'s Contact Information', question_nums: ['2'] },
        { label: 'Section III: Reporting Period', question_nums: ['3'] },
        { label: 'Section IV: In-Home Care And Care Facility Expenses', question_nums: ['4'] },
        { label: 'Section V: Other Medical Expenses', question_nums: ['5'] },
        { label: 'Section VI: Mileage', question_nums: ['6'] },
        { label: 'Section VII: Certification And Signature', question_nums: ['7'] },
        { label: 'Section VIII: Witness To Signature', question_nums: ['8'] },
        { label: 'Addendum A: In-Home Care Or Care Facility Expenses', question_nums: ['9'] },
        { label: 'Addendum B: Other Medical Expenses', question_nums: ['10'] },
        { label: 'Addendum C: Mileage For Privately Owned Vehicle Travel For Medical Expenses', question_nums: ['11'] },
        { label: 'Worksheet 1: Worksheet For A Residential Care, Adult Daycare, Or A Similar Facility',
          question_nums: ['12'] },
        { label: 'Worksheet 2: Worksheet For In-Home Attendant Expenses', question_nums: ['13'] }
      ].freeze

      # The list of section classes for form expansion and key building
      SECTION_CLASSES = [Section1, Section2, Section3,
                         Section4, Section5, Section6,
                         Section7, Section8, Section9,
                         Section10, Section11, Section12].freeze

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
