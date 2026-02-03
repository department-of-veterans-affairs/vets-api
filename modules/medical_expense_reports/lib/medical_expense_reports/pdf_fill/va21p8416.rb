# frozen_string_literal: true

require 'hexapdf'
require 'pdf_utilities/datestamp_pdf'
require 'pdf_fill/forms/form_base'
require 'pdf_fill/forms/form_helper'
require 'pdf_fill/hash_converter'
require 'medical_expense_reports/constants'
require 'medical_expense_reports/helpers'
require 'medical_expense_reports/pdf_fill/sections/section_01'
require 'medical_expense_reports/pdf_fill/sections/section_02'
require 'medical_expense_reports/pdf_fill/sections/section_03'
require 'medical_expense_reports/pdf_fill/sections/section_04'
require 'medical_expense_reports/pdf_fill/sections/section_05'
require 'medical_expense_reports/pdf_fill/sections/section_06'
require 'medical_expense_reports/pdf_fill/sections/section_07'
require 'medical_expense_reports/pdf_fill/sections/addendum_a'
require 'medical_expense_reports/pdf_fill/sections/addendum_b'
require 'medical_expense_reports/pdf_fill/sections/addendum_c'

module MedicalExpenseReports
  module PdfFill
    # The Va21p8416 Form
    class Va21p8416 < ::PdfFill::Forms::FormBase
      include ::PdfFill::Forms::FormHelper
      include MedicalExpenseReports::Helpers

      # The Form ID
      FORM_ID = MedicalExpenseReports::FORM_ID

      # Hash iterator
      ITERATOR = ::PdfFill::HashConverter::ITERATOR

      # The path to the PDF template for the form
      TEMPLATE = "#{MedicalExpenseReports::MODULE_PATH}/lib/medical_expense_reports/pdf_fill/pdfs/#{FORM_ID}.pdf".freeze

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
                         Section7,
                         AddendumA, AddendumB, AddendumC].freeze

      key = {}

      SECTION_CLASSES.each { |section| key.merge!(section::KEY) }

      # Form configuration hash
      KEY = key.freeze

      # Name of the AcroForm field that contains the signature widget
      SIGNATURE_FIELD_NAME = Section7::KEY.dig('statementOfTruthSignature', :key)
      # Font size (points) used when stamping the signature
      SIGNATURE_FONT_SIZE = 10
      # Horizontal padding (points) applied to the derived signature x coordinate
      SIGNATURE_PADDING_X = 2
      # Vertical padding (points) applied to the derived signature y coordinate
      SIGNATURE_PADDING_Y = 1
      # Fallback coordinates if runtime extraction fails
      STATIC_SIGNATURE_COORDINATES = {
        x: 40.8,
        y: 295.3,
        page_number: 4 # zero-indexed; 4 == page 5
      }.freeze

      # Default label column width (points) for redesigned extras in this form
      DEFAULT_LABEL_WIDTH = 130

      # Stamp a typed signature string onto the PDF using DatestampPdf.
      #
      # @param pdf_path [String] Path to the PDF to stamp
      # @param form_data [Hash] The form data containing the signature
      # @return [String] Path to the stamped PDF (or the original path if signature is blank/on failure)
      def self.stamp_signature(pdf_path, form_data)
        signature_text = form_data['statementOfTruthSignature']
        return pdf_path if signature_text.blank?

        coordinates = signature_overlay_coordinates(pdf_path) || STATIC_SIGNATURE_COORDINATES

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
      rescue => e
        Rails.logger.error('MedicalExpenseReports 21P-8416: Error stamping signature',
                           error: e.message, backtrace: e.backtrace)
        pdf_path
      end

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

      # Derive signature widget coordinates from the PDF template so the stamped
      # signature text can be positioned correctly.
      #
      # @param pdf_path [String] Path to the PDF template
      # @return [Hash, nil] Coordinates hash of the form
      #   `{ x: Float, y: Float, page_number: Integer }` or nil on failure
      def self.signature_overlay_coordinates(pdf_path)
        if Flipper.enabled?(:acroform_debug_logs)
          Rails.logger.info("MedicalExpenseReports::PdfFill::Va21p8416 HexaPDF template: #{pdf_path}")
        end

        doc = HexaPDF::Document.open(pdf_path)
        field = doc.acro_form&.field_by_name(SIGNATURE_FIELD_NAME)
        widget = field&.each_widget&.first
        return unless widget

        rect = widget[:Rect]
        page = doc.object(widget[:P])
        page_index = doc.pages.each_with_index.find { |page_obj, _i| page_obj == page }&.last
        return unless rect && page_index

        llx, lly, _urx, ury = rect
        height = ury - lly
        y = lly + [((height - SIGNATURE_FONT_SIZE) / 2.0), 0].max + SIGNATURE_PADDING_Y

        { x: llx + SIGNATURE_PADDING_X, y:, page_number: page_index }
      rescue => e
        Rails.logger.error('MedicalExpenseReports 21P-8416: Error deriving signature coordinates',
                           error: e.message, backtrace: e.backtrace)
        nil
      end
    end
  end
end
