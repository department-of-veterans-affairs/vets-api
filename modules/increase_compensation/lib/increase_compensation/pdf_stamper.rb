# frozen_string_literal: true

require 'hexapdf'
require 'pdf_utilities/datestamp_pdf'
require 'pdf_utilities/pdf_stamper'

module IncreaseCompensation
  class PdfStamper
    # Name of the AcroForm field that contains the claimant signature widget (27)
    SIGNATURE_FIELD_NAME = 'form1[0].#subform[4].SignatureField11[0]'
    # Font size (points) used when stamping the signature
    SIGNATURE_FONT_SIZE = 10
    # Horizontal padding (points) applied to the derived signature x coordinate
    SIGNATURE_PADDING_X = 2
    # Vertical padding (points) applied to the derived signature y coordinate
    SIGNATURE_PADDING_Y = 1
    # Coordinates of signature box
    STATIC_SIGNATURE_COORDINATES = {
      x: 40.8,
      y: 416,
      page_number: 3 # zero-indexed;
    }.freeze

    # Stamp a typed signature string onto the PDF using DatestampPdf.
    #
    # @param pdf_path [String] Path to the PDF to stamp
    # @param form_data [Hash] The form data containing the signature
    # @return [String] Path to the stamped PDF (or the original path if signature is blank/on failure)
    def self.stamp_signature(pdf_path, form_data)
      signature_text = signature_text_for(form_data)
      return pdf_path if signature_text.blank?

      stamp_pdf(pdf_path, signature_text, STATIC_SIGNATURE_COORDINATES)
    rescue => e
      Rails.logger.error(
        'Form 21-8940: Error stamping signature',
        error: e.message,
        backtrace: e.backtrace
      )
      pdf_path
    end

    def self.signature_text_for(form_data)
      form_data['signature'].presence || veteran_full_name(form_data)
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
