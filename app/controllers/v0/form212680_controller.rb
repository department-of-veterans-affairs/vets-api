# frozen_string_literal: true

module V0
  class Form212680Controller < ApplicationController
    service_tag 'form-21-2680'
    skip_before_action :authenticate, only: %i[download_pdf submit]

    # POST /v0/form212680/download_pdf
    # Generate and download a pre-filled PDF with veteran sections (I-V) completed
    # Physician sections (VI-VIII) are left blank for manual completion
    def download_pdf
      claim = create_claim
      validate_claim(claim)

      pdf_path = generate_and_send_pdf(claim)
      StatsD.increment('form212680.pdf.generated')
    ensure
      if pdf_path.presence && pdf_path.exclude?('spec/fixtures/files/')
        Common::FileHelpers.delete_file_if_exists(pdf_path)
      end
    end

    # POST /v0/form212680/submit
    # Stub endpoint for future submission functionality
    def submit
      message = 'Form submission stub - not yet implemented. ' \
                'Please use the existing VA document upload system at va.gov/upload-supporting-documents'
      render json: { message: }, status: :ok
    end

    private

    def create_claim
      form_data = params.require(:form212680).to_unsafe_h
      SavedClaim::Form212680.new(form: form_data.to_json)
    end

    def validate_claim(claim)
      return if claim.veteran_sections_complete?

      error_messages = claim.veteran_sections_errors.join('; ')
      raise Common::Exceptions::UnprocessableEntity.new(detail: error_messages) unless error_messages.empty?
    end

    def generate_and_send_pdf(claim)
      pdf_path = claim.to_pdf
      pdf_content = File.read(pdf_path)

      send_data pdf_content,
                filename: "VA_Form_21-2680_#{Time.current.strftime('%Y%m%d_%H%M%S')}.pdf",
                type: 'application/pdf',
                disposition: 'attachment'

      pdf_path
    end
  end
end
