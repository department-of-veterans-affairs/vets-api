# frozen_string_literal: true

module V0
  class Form212680Controller < ApplicationController
    service_tag 'form-21-2680'
    skip_before_action :authenticate, only: %i[download_pdf]

    # POST /v0/form212680/download_pdf
    # Generate and download a pre-filled PDF with veteran sections (I-V) completed
    # Physician sections (VI-VIII) are left blank for manual completion
    def download_pdf
      params.require('form')
      # using request.raw_post to avoid the middleware that transforms the JSON keys to snake case
      form_body = JSON.parse(request.raw_post)['form'].to_json

      claim = SavedClaim::Form212680.new(form: form_body)
      if claim.save
        pdf_path = claim.generate_prefilled_pdf

        send_data File.read(pdf_path),
                  filename: "VA_Form_21-2680_#{Time.current.strftime('%Y%m%d_%H%M%S')}.pdf",
                  type: 'application/pdf',
                  disposition: 'attachment'
      else
        raise(Common::Exceptions::ValidationErrors, claim)
      end
    end
  end
end
