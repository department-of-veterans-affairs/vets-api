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
      START_PAGE = 14

      # Map question numbers to descriptive titles for overflow attachments
      QUESTION_KEY = {
        1 => 'Veteran name',
        2 => 'Social Security Number',
        3 => 'VA file number',
        4 => 'Claimant name',
        5 => 'Claimant Social Security Number',
        6 => 'Claimant telephone number',
        7 => 'Claimant type',
        8 => 'Income/net worth date range',
        9 => 'Unassociated incomes',
        10 => 'Associated incomes',
        11 => 'Owned assets',
        12 => 'Royalties and other properties',
        13 => 'Asset transfers',
        14 => 'Trusts',
        15 => 'Annuities',
        16 => 'Unreported assets',
        17 => 'Discontinued incomes',
        18 => 'Income receipt waivers',
        19 => 'Statement of truth'
      }.freeze

      # V2-style sections grouping question numbers for overflow pages
      SECTIONS = [
        { label: 'Section I: Veteran Information', question_nums: [1, 2, 3] },
        { label: 'Section II: Claimant Information', question_nums: [4, 5, 6, 7, 8] },
        { label: 'Section III: Unassociated Incomes', question_nums: [9] },
        { label: 'Section IV: Associated Incomes', question_nums: [10] },
        { label: 'Section V: Owned Assets', question_nums: [11] },
        { label: 'Section VI: Royalties and Other Properties', question_nums: [12] },
        { label: 'Section VII: Asset Transfers', question_nums: [13] },
        { label: 'Section VIII: Trusts', question_nums: [14] },
        { label: 'Section IX: Annuities', question_nums: [15] },
        { label: 'Section X: Unreported Assets', question_nums: [16] },
        { label: 'Section XI: Discontinued Incomes', question_nums: [17] },
        { label: 'Section XII: Income Receipt Waivers', question_nums: [18] },
        { label: 'Section XIII: Statement of Truth', question_nums: [19] }
      ].freeze

      # The list of section classes for form expansion and key building
      SECTION_CLASSES = [Section1, Section2, Section3, Section4,
                         Section5, Section6, Section7, Section8,
                         Section9, Section10, Section11, Section12,
                         Section13].freeze

      key = {}

      SECTION_CLASSES.each { |section| key = key.merge(section::KEY) }

      # Form configuration hash
      KEY = key.freeze

      # Default label column width (points) for redesigned extras in this form
      DEFAULT_LABEL_WIDTH = 300

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
