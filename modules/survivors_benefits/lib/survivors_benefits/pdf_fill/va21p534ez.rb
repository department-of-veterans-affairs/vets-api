# frozen_string_literal: true

require 'hexapdf'
require 'pdf_fill/forms/form_base'
require 'pdf_fill/forms/form_helper'
require 'pdf_fill/hash_converter'
require 'pdf_utilities/datestamp_pdf'
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
        { question_number: '1', question_text: 'Veteran\'s Identification Information' },
        { question_number: '2', question_text: 'Claimant\'s Contact Information' },
        { question_number: '3', question_text: 'Veteran\'s Service Information' },
        { question_number: '4', question_text: 'Marital Information' },
        { question_number: '5', question_text: 'Marital History' },
        { question_number: '6', question_text: 'Child of the Veteran Information' },
        { question_number: '7', question_text: 'Dependency and Indemnity Compensation (DIC)' },
        { question_number: '8', question_text: 'Nursing Home or Increased Survivors Entitlement' },
        { question_number: '9', question_text: 'Income and Assets' },
        { question_number: '10', question_text: 'Information About Your Medical or Other Expenses' },
        { question_number: '11', question_text: 'Direct Deposit Information (Must Complete)' },
        { question_number: '12', question_text: 'Claim Certification and Signature (Must Complete)' },
        { question_number: '13', question_text: 'Witness to Signature' }
      ].freeze

      # V2-style sections grouping question numbers for overflow pages
      SECTIONS = [
        { label: 'Section I: Veteran\'s Identification Information', question_nums: ['1'] },
        { label: 'Section II: Claimant\'s Contact Information', question_nums: ['2'] },
        { label: 'Section III: Veteran\'s Service Information', question_nums: ['3'] },
        { label: 'Section IV: Marital Information', question_nums: ['4'] },
        { label: 'Section V: Marital History', question_nums: ['5'] },
        { label: 'Section VI: Child of the Veteran Information', question_nums: ['6'] },
        { label: 'Section VII: Dependency and Indemnity Compensation (DIC)', question_nums: ['7'] },
        { label: 'Section VIII: Nursing Home or Increased Survivors Entitlement', question_nums: ['8'] },
        { label: 'Section IX: Income and Assets', question_nums: ['9'] },
        { label: 'Section X: Information About Your Medical or Other Expenses', question_nums: ['10'] },
        { label: 'Section XI: Direct Deposit Information (Must Complete)', question_nums: ['11'] },
        { label: 'Section XII: Claim Certification and Signature (Must Complete)', question_nums: ['12'] },
        { label: 'Section XIII: Witness to Signature', question_nums: ['13'] }
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

      # Name of the AcroForm field that contains the claimant signature widget (12B)
      SIGNATURE_FIELD_NAME = 'form1[0].#subform[218].SignatureField1[1]'
      # Font size (points) used when stamping the signature
      SIGNATURE_FONT_SIZE = 10
      # Horizontal padding (points) applied to the derived signature x coordinate
      SIGNATURE_PADDING_X = 2
      # Vertical padding (points) applied to the derived signature y coordinate
      SIGNATURE_PADDING_Y = 1
      # Zero-based page index where the signature widget lives (visible page 18)
      SIGNATURE_PAGE_INDEX = 17

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

      # Stamp a typed signature string onto the PDF using DatestampPdf.
      #
      # @param pdf_path [String] Path to the PDF to stamp
      # @param form_data [Hash] The form data containing the signature
      # @return [String] Path to the stamped PDF (or the original path if signature is blank/on failure)
      def self.stamp_signature(pdf_path, form_data)
        return pdf_path if pdf_path.blank?

        signature_text = signature_text_for(form_data)
        return pdf_path if signature_text.blank?

        coordinates = signature_overlay_coordinates(pdf_path) ||
                      signature_overlay_coordinates(TEMPLATE)
        unless coordinates
          Rails.logger.warn(
            'SurvivorsBenefits 21P-534EZ: Unable to derive signature coordinates; returning original PDF',
            pdf_path:
          )
          return pdf_path
        end

        stamp_pdf(pdf_path, signature_text, coordinates)
      rescue => e
        Rails.logger.error('SurvivorsBenefits 21P-534EZ: Error stamping signature',
                           error: e.message, backtrace: e.backtrace)
        pdf_path
      end

      # Derive signature widget coordinates from the PDF template so the stamped
      # signature text can be positioned correctly.
      #
      # @param pdf_path [String] Path to the PDF template
      # @return [Hash, nil] Coordinates hash of the form
      #   `{ x: Float, y: Float, page_number: Integer }` or nil on failure
      def self.signature_overlay_coordinates(pdf_path = TEMPLATE)
        signature_overlay_coordinates_for(pdf_path)
      rescue => e
        Rails.logger.error('SurvivorsBenefits 21P-534EZ: Error deriving signature coordinates',
                           error: e.message, backtrace: e.backtrace)
        nil
      end

      def self.signature_overlay_coordinates_for(pdf_path)
        if Flipper.enabled?(:acroform_debug_logs)
          Rails.logger.info("SurvivorsBenefits::PdfFill::Va21p534ez HexaPDF template: #{pdf_path}")
        end

        HexaPDF::Document.open(pdf_path) do |doc|
          field = doc.acro_form&.field_by_name(SIGNATURE_FIELD_NAME)
          widget = field&.each_widget&.first
          next unless widget

          rect = widget[:Rect]
          next unless rect

          llx, lly, _urx, ury = rect
          height = ury - lly
          y = lly + [((height - SIGNATURE_FONT_SIZE) / 2.0), 0].max + SIGNATURE_PADDING_Y

          { x: llx + SIGNATURE_PADDING_X, y:, page_number: SIGNATURE_PAGE_INDEX }
        end
      end

      def self.signature_text_for(form_data)
        form_data['claimantSignature'].presence ||
          form_data['statementOfTruthSignature'].presence ||
          claimant_full_name(form_data)
      end

      def self.claimant_full_name(form_data)
        [form_data&.dig('claimantFullName', 'first'),
         form_data&.dig('claimantFullName', 'middle'),
         form_data&.dig('claimantFullName', 'last')].compact_blank.join(' ')
      end

      def self.stamp_pdf(pdf_path, signature_text, coordinates)
        PDFUtilities::DatestampPdf.new(pdf_path).run(
          text: signature_text,
          x: coordinates[:x],
          y: coordinates[:y],
          page_number: coordinates[:page_number],
          size: SIGNATURE_FONT_SIZE,
          text_only: true,
          timestamp: '',
          template: pdf_path,
          multistamp: true
        )
      end
    end
  end
end
