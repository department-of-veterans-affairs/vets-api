# frozen_string_literal: true

require 'pdf_fill/forms/form_base'
require 'pdf_fill/forms/form_helper'
require 'pdf_fill/hash_converter'
require 'income_and_assets/constants'
require 'income_and_assets/helpers'
require 'income_and_assets/pdf_fill/sections/section_01'
require 'income_and_assets/pdf_fill/sections/section_02'
require 'income_and_assets/pdf_fill/sections/section_03'
require 'income_and_assets/pdf_fill/sections/section_04'
require 'income_and_assets/pdf_fill/sections/section_05'
require 'income_and_assets/pdf_fill/sections/section_06'
require 'income_and_assets/pdf_fill/sections/section_07'
require 'income_and_assets/pdf_fill/sections/section_08'
require 'income_and_assets/pdf_fill/sections/section_09'
require 'income_and_assets/pdf_fill/sections/section_10'
require 'income_and_assets/pdf_fill/sections/section_11'
require 'income_and_assets/pdf_fill/sections/section_12'
require 'income_and_assets/pdf_fill/sections/section_13'

module IncomeAndAssets
  module PdfFill
    # The Va21p0969 Form
    class Va21p0969 < ::PdfFill::Forms::FormBase
      include ::PdfFill::Forms::FormHelper
      include IncomeAndAssets::Helpers

      # The Form ID
      FORM_ID = IncomeAndAssets::FORM_ID

      # Hash iterator
      ITERATOR = ::PdfFill::HashConverter::ITERATOR

      # The path to the PDF template for the form
      TEMPLATE = "#{IncomeAndAssets::MODULE_PATH}/lib/income_and_assets/pdf_fill/pdfs/#{FORM_ID}.pdf".freeze

      # Starting page number for overflow pages
      START_PAGE = 11

      # Map question numbers to descriptive titles for overflow attachments
      QUESTION_KEY = {
        1 => 'Veteran\'s Identification Information',
        2 => 'Claimant\'s Identification Information',
        3 => 'Recurring Income Not Associated with Accounts or Assets',
        4 => 'Associated Incomes',
        5 => 'Income and Net Worth Associated with Owned Assets',
        6 => 'Income and Net Worth Associated with Royalties and Other Properties',
        7 => 'Asset Transfers',
        8 => 'Trusts',
        9 => 'Annuities',
        10 => 'Assets Previously Not Reported',
        11 => 'Discontinued or Irregular Income',
        12 => 'Waiver of Receipt of Income'
      }.freeze

      # V2-style sections grouping question numbers for overflow pages
      SECTIONS = [
        { label: 'Section I: Veteran\'s Identification Information', question_nums: [1] },
        { label: 'Section II: Claimant\'s Identification Information', question_nums: [2] },
        { label: 'Section III: Recurring Income Not Associated with Accounts or Assets', question_nums: [3] },
        { label: 'Section IV: Associated Incomes', question_nums: [4] },
        { label: 'Section V: Income and Net Worth Associated with Owned Assets', question_nums: [5] },
        { label: 'Section VI: Income and Net Worth Associated with Royalties and Other Properties',
          question_nums: [6] },
        { label: 'Section VII: Asset Transfers', question_nums: [7] },
        { label: 'Section VIII: Trusts', question_nums: [8] },
        { label: 'Section IX: Annuities', question_nums: [9] },
        { label: 'Section X: Assets Previously Not Reported', question_nums: [10] },
        { label: 'Section XI: Discontinued or Irregular Income', question_nums: [11] },
        { label: 'Section XII: Waiver of Receipt of Income', question_nums: [12] }
      ].freeze

      # The list of section classes for form expansion and key building
      SECTION_CLASSES = [Section1, Section2, Section3, Section4,
                         Section5, Section6, Section7, Section8,
                         Section9, Section10, Section11, Section12,
                         Section13].freeze

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
