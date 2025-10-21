# frozen_string_literal: true

module AppealsApi::PdfConstruction::NoticeOfDisagreement::Feb2025::Pages
  class TimeExtensionReason
    attr_reader :pdf, :form_data

    # @param [Prawn::Document] pdf
    def initialize(pdf, form_data)
      @pdf = pdf
      @form_data = form_data
    end

    def build!
      return pdf unless form_data.requesting_extension?

      pdf.start_new_page
      pdf.text(extension_text, inline_format: true)
      pdf
    end

    private

    def extension_text
      "\n<b>Time Extension Reason:</b>\n#{form_data.extension_reason}\n"
    end
  end
end
