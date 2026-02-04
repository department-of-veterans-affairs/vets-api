# frozen_string_literal: true

require 'hexapdf'
require 'pdf_utilities/datestamp_pdf'
require 'pdf_utilities/pdf_stamper'

module IncreaseCompensation
  class PdfStamper
    # Name of the AcroForm field that contains the claimant signature widget (12B)
    SIGNATURE_FIELD_NAME = 'form1[0].#subform[4].SignatureField11[0]'
    # Font size (points) used when stamping the signature
    SIGNATURE_FONT_SIZE = 10
    # Horizontal padding (points) applied to the derived signature x coordinate
    SIGNATURE_PADDING_X = 2
    # Vertical padding (points) applied to the derived signature y coordinate
    SIGNATURE_PADDING_Y = 1

    # Stamp a typed signature string onto the PDF using DatestampPdf.
    #
    # @param pdf_path [String] Path to the PDF to stamp
    # @param form_data [Hash] The form data containing the signature
    # @return [String] Path to the stamped PDF (or the original path if signature is blank/on failure)
    def self.stamp_signature(pdf_path, form_data)
      signature_text = signature_text_for(form_data)
      return pdf_path if signature_text.blank?

      coordinates = signature_overlay_coordinates(pdf_path)
      return pdf_path unless coordinates

      stamp_pdf(pdf_path, signature_text, coordinates)
    rescue => e
      Rails.logger.error(
        'Form 21-8940: Error stamping signature',
        error: e.message,
        backtrace: e.backtrace
      )
      pdf_path
    end

    # Derive signature widget coordinates from the PDF template so the stamped
    # signature text can be positioned correctly.
    #
    # @param pdf_path [String] Path to the PDF template
    # @return [Hash, nil] Coordinates hash of the form
    #   `{ x: Float, y: Float, page_number: Integer }` or nil on failure
    def self.signature_overlay_coordinates(pdf_path = TEMPLATE) # rubocop:disable Metrics/MethodLength
      if Flipper.enabled?(:acroform_debug_logs)
        Rails.logger.info("IncreaseCompensation::PdfStamper HexaPDF template: #{pdf_path}")
      end
      doc = HexaPDF::Document.open(pdf_path)
      return unless doc.validate(auto_correct: false)

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
      Rails.logger.error(
        'Form 21-8940: Error deriving signature coordinates',
        error: e.message,
        backtrace: e.backtrace
      )
      nil
    end

    def self.signature_text_for(form_data)
      form_data['statementOfTruthSignature'].presence ||
        form_data['signature'].presence ||
        veteran_full_name(form_data)
    end

    def self.veteran_full_name(form_data)
      [
        form_data.dig('veteranFullName', 'first'),
        form_data.dig('veteranFullName', 'last')
      ].compact_blank.join(' ')
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
