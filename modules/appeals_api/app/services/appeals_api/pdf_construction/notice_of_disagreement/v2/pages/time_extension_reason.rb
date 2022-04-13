# frozen_string_literal: true

module AppealsApi::PdfConstruction::NoticeOfDisagreement::V2::Pages
  class TimeExtensionReason
    def initialize(pdf, form_data)
      @pdf = pdf # Prawn::Document
      @form_data = form_data
    end

    def build!
      return pdf unless form_data.requesting_extension?

      pdf.start_new_page
      pdf.text(extension_text, inline_format: true)
      pdf
    end

    private

    attr_accessor :pdf, :form_data

    def extension_text
      "\n<b>Time Extension Reason:</b>\n#{form_data.extension_reason}\n"
    end
  end
end
