# frozen_string_literal: true

module V0
  class Form212680Controller < ApplicationController
    service_tag 'form-21-2680'
    skip_before_action :authenticate, only: %i[download_pdf submit]

    # POST /v0/form212680/download_pdf
    # Generate and download a pre-filled PDF with veteran sections (I-V) completed
    # Physician sections (VI-VIII) are left blank for manual completion
    def download_pdf
      pdf_path='lib/pdf_fill/forms/pdfs/21-2680.pdf'
      pdf_content = File.read(pdf_path)

      send_data pdf_content,
            filename: "VA_Form_21-2680_#{Time.current.strftime('%Y%m%d_%H%M%S')}.pdf",
            type: 'application/pdf',
            disposition: 'attachment'

    ensure
      Common::FileHelpers.delete_file_if_exists(pdf_path) if pdf_path.presence
    end

    # POST /v0/form212680/submit
    # Stub endpoint for future submission functionality
    def submit
      message = 'Form submission stub - not yet implemented. ' \
                'Please use the existing VA document upload system at va.gov/upload-supporting-documents'
      render json: { message: }, status: :ok
    end
  end
end
