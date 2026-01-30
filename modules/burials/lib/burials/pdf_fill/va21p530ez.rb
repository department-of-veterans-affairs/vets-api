# frozen_string_literal: true

require 'pdf_fill/hash_converter'
require 'pdf_fill/forms/form_base'
require 'pdf_fill/forms/form_helper'
require 'string_helpers'
require_relative 'constants'

require_relative 'sections/section_01'
require_relative 'sections/section_02'
require_relative 'sections/section_03'
require_relative 'sections/section_04'
require_relative 'sections/section_05'
require_relative 'sections/section_06'
require_relative 'sections/section_07'

require_relative 'sections/section_01_v2'
require_relative 'sections/section_02_v2'
require_relative 'sections/section_03_v2'
require_relative 'sections/section_04_v2'
require_relative 'sections/section_05_v2'
require_relative 'sections/section_06_v2'
require_relative 'sections/section_07_v2'
require_relative 'sections/section_08_v2'

module Burials
  module PdfFill
    # Forms module
    module Forms
      # Burial 21P-530EZ PDF Filler class
      class Va21p530ez < ::PdfFill::Forms::FormBase
        include ::PdfFill::Forms::FormHelper
        include Helpers

        # The ID of the form being processed
        FORM_ID = '21P-530EZ'

        # An external iterator used in data processing
        ITERATOR = ::PdfFill::HashConverter::ITERATOR

        # Starting page number for overflow pages
        START_PAGE = 10

        # Default label column width (points) for redesigned extras in this form
        DEFAULT_LABEL_WIDTH = 130

        # Map question numbers to descriptive titles for overflow attachments
        QUESTION_KEY = [
          { question_number: '1', question_text: "Deceased Veteran's Name" },
          { question_number: '2', question_text: "Deceased Veteran's Social Security Number" },
          { question_number: '3', question_text: "Veteran's Date of Birth" },
          { question_number: '4', question_text: 'VA File Number' },
          { question_number: '5', question_text: "Veteran's Date of Death" },
          { question_number: '6', question_text: "Veteran's Date of Burial" },
          { question_number: '7', question_text: "Claimant's Name" },
          { question_number: '8', question_text: "Claimant's Social Security Number" },
          { question_number: '9', question_text: "Claimant's Date of Birth" },
          { question_number: '10', question_text: "Claimant's Address" },
          { question_number: '11', question_text: "Claimant's International Phone Number" },
          { question_number: '12', question_text: 'E-Mail Address' },
          { question_number: '13', question_text: 'Relationship to Veteran' },
          { question_number: '14', question_text: 'Military Service Information' },
          { question_number: '15', question_text: 'Other Names Veteran Served Under' },
          { question_number: '16', question_text: 'Place of Burial Plot, Interment Site, or Final Resting Place' },
          { question_number: '17', question_text: 'National or Federal Cemetery' },
          { question_number: '18', question_text: 'State Cemetery or Tribal Trust Land' },
          { question_number: '19', question_text: 'Government or Employer Contribution' },
          { question_number: '26', question_text: "Where Did the Veteran's Death Occur" },
          { question_number: '27', question_text: 'Burial Allowance Requested' },
          { question_number: '28', question_text: 'Previously Received Allowance' },
          { question_number: '29', question_text: 'Burial Expense Responsibility' },
          { question_number: '30', question_text: 'Plot/Interment Expense Responsibility' },
          { question_number: '31', question_text: 'Claimant Signature' },
          { question_number: '32', question_text: 'Firm, Corporation, or State Agency Information' }
        ].freeze

        # V2-style sections grouping question numbers for overflow pages
        SECTIONS = [
          { label: 'Section I: Deceased Veteran\'s Name', question_nums: ['1'] },
          { label: 'Section II: Deceased Veteran\'s Social Security Number', question_nums: ['2'] },
          { label: 'Section III: VA File Number', question_nums: ['3'] },
          { label: 'Section IV: Veteran\'s Date of Birth', question_nums: ['4'] },
          { label: 'Section V: Veteran\'s Date of Death', question_nums: ['5'] },
          { label: 'Section VI: Veteran\'s Date of Burial', question_nums: ['6'] },
          { label: 'Section VII: Claimant\'s Identification Information', question_nums: %w[7 8 9] },
          { label: 'Section VIII: Claimant\'s Contact Information', question_nums: %w[10 11 12] },
          { label: 'Section IX: Relationship to Veteran', question_nums: ['13'] },
          { label: 'Section X: Military Service Information', question_nums: %w[14 15] },
          { label: 'Section XI: Burial Information', question_nums: %w[16 17 18] },
          { label: 'Section XII: Government Contributions and Death Location', question_nums: %w[19 26] },
          { label: 'Section XIII: Burial Allowance and Expenses', question_nums: %w[27 28 29 30] },
          { label: 'Section XIV: Signatures and Certifications', question_nums: %w[31 32] }
        ].freeze

        # A mapping of care facilities to their labels
        PLACE_OF_DEATH_KEY = {
          'vaMedicalCenter' => 'VA MEDICAL CENTER',
          'stateVeteransHome' => 'STATE VETERANS HOME',
          'nursingHome' => 'NURSING HOME UNDER VA CONTRACT'
        }.freeze

        # Mapping of the filled out form into JSON
        key = {}

        # The list of section classes for form expansion and key building
        SECTION_CLASSES = [Section1, Section2, Section3, Section4, Section5, Section6, Section7].freeze

        # V2 configuration (update as you go)
        SECTION_CLASSES_V2 = [Section1V2, Section2V2, Section3V2, Section4V2, Section5V2,
                              Section6V2, Section7V2, Section8V2].freeze

        # V2 question key mapping question numbers to descriptive titles for overflow attachment
        # These are placeholders and will be updated as V2 sections are implemented
        QUESTION_KEY_V2 = [
          { question_number: '1', question_text: "Deceased Veteran's Name" },
          { question_number: '2', question_text: "Deceased Veteran's Social Security Number" },
          { question_number: '3', question_text: 'VA File Number' },
          { question_number: '4', question_text: "Veteran's Date of Birth" },
          { question_number: '5', question_text: "Veteran's Date of Death" },
          { question_number: '6', question_text: "Veteran's Date of Burial" },
          { question_number: '7', question_text: "Claimant's Name" },
          { question_number: '8', question_text: "Claimant's Social Security Number" },
          { question_number: '9', question_text: "Claimant's Date of Birth" },
          { question_number: '10', question_text: "Claimant's Address" },
          { question_number: '11', question_text: "Claimant's International Phone Number" },
          { question_number: '12', question_text: 'E-Mail Address' },
          { question_number: '13', question_text: 'Relationship to Veteran' },
          { question_number: '14', question_text: 'Other Names Veteran Served Under' },
          { question_number: '15', question_text: 'Date Initially Entered Active Duty' },
          { question_number: '16', question_text: 'Final Release Date From Active Duty' },
          { question_number: '17', question_text: 'Service Number' },
          { question_number: '18', question_text: 'Branch of Service' },
          { question_number: '19', question_text: 'Place of Last Separation' },
          { question_number: '20', question_text: 'Veteran Prisoner of War Status' },
          { question_number: '21', question_text: 'Place of Burial Plot, Interment Site, or Final Resting Place' },
          { question_number: '22', question_text: 'National or Federal Cemetery' },
          { question_number: '23', question_text: 'State Cemetery or Tribal Trust Land' },
          { question_number: '24', question_text: 'Government or Employer Contribution' },
          { question_number: '25', question_text: 'Resposible for the Veteran\'s Plot' },
          { question_number: '26', question_text: 'Burial Allowance Requested' },
          { question_number: '27', question_text: 'Did Veteran Pass Away Under VA Coverage' },
          { question_number: '28', question_text: 'Received VA Burial Allowance' },
          { question_number: '29', question_text: 'Burial Expense Responsibility' },
          { question_number: '30', question_text: 'Plot/Interment Expense Responsibility' },
          { question_number: '31', question_text: 'Direct Deposit Information' },
          { question_number: '32', question_text: 'Claimant Signature' },
          { question_number: '33', question_text: 'Firm, Corporation, or State Agency Information' }
        ].freeze

        # V2 sections grouping question numbers for overflow pages
        # These are placeholders and will be updated as V2 sections are implemented
        SECTIONS_V2 = [
          { label: 'Section I: Personal Identification Of Veteran', question_nums: %w[1 2 3 4 5 6] },
          { label: 'Section II: Claimant\'s Information', question_nums: %w[7 8 9 10 11 12 13] },
          { label: 'Section III: Veteran\'s Service Information', question_nums: %w[14 15 16 17 18 19 20] },
          { label: 'Section IV: Final Resting Place Information', question_nums: %w[21 22 23 24 25] },
          { label: 'Section V: Burial Allowance and Expenses', question_nums: %w[26 27 28 29] },
          { label: 'Section VI: Claim For Transportation Allowance', question_nums: %w[30] },
          { label: 'Section VII: Direct Deposit Information', question_nums: %w[31] },
          { label: 'Section VIII: Certification and Signature', question_nums: %w[32 33] },
          { label: 'Section IX: Witnesses To Signature', question_nums: %w[34 35] },
          { label: 'Section X: Alternate Signer Certification', question_nums: %w[36] }
        ].freeze

        # form configuration hash
        KEY = key.freeze

        ##
        # Returns the dynamic PDF field mapping key based on the current version.
        # Builds the key by merging all section KEY constants.
        #
        # @return [Hash] The PDF field mapping for the current version
        def key
          @key ||= begin
            k = {}
            section_classes.each { |section| k.merge!(section::KEY) }
            k.freeze
          end
        end

        ##
        # The crux of the class, this method merges all the data that has been converted into @form_data
        #
        # @param _options [Hash]
        #
        # @return [Hash]
        def merge_fields(_options = {})
          ssn = @form_data['veteranSocialSecurityNumber']
          ['', '2', '3'].each do |suffix|
            @form_data["veteranSocialSecurityNumber#{suffix}"] = split_ssn(ssn)
          end

          section_classes.each { |section| section.new.expand(@form_data) }

          @form_data
        end

        ##
        # Returns the question key for overflow pages based on the current version.
        # Controlled by the burial_pdf_form_alignment Flipper flag.
        #
        # @return [Array<Hash>] Array of question mappings with question_number and question_text
        def question_key
          Burials.use_v2? ? QUESTION_KEY_V2 : QUESTION_KEY
        end

        ##
        # Returns the section classes to use based on the current version (V1 or V2).
        # Controlled by the burial_pdf_form_alignment Flipper flag.
        #
        # @return [Array<Class>] Array of section classes (V1 or V2)
        def section_classes
          Burials.use_v2? ? SECTION_CLASSES_V2 : SECTION_CLASSES
        end

        ##
        # Returns the sections configuration for overflow pages based on the current version.
        # Controlled by the burial_pdf_form_alignment Flipper flag.
        #
        # @return [Array<Hash>] Array of section definitions with label and question_nums
        def sections
          Burials.use_v2? ? SECTIONS_V2 : SECTIONS
        end

        ##
        # Returns the PDF template path. Uses Burials module's dynamic path resolution.
        #
        # @return [String] Path to the PDF template file
        def template
          Burials.pdf_path
        end
      end
    end
  end
end
