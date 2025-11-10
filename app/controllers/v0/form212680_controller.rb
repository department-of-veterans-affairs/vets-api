# frozen_string_literal: true

module V0
  class Form212680Controller < ApplicationController
    include RetriableConcern
    include PdfFill::Forms::FormHelper

    service_tag 'form-21-2680'
    skip_before_action :authenticate, only: %i[download_pdf]
    before_action :load_user
    before_action :check_feature_enabled

    # POST /v0/form212680/download_pdf
    # Generate and download a pre-filled PDF with veteran sections (I-V) completed
    # Physician sections (VI-VIII) are left blank for manual completion
    def download_pdf
      # using request.raw_post to avoid the middleware that transforms the JSON keys to snake case
      pdf_path = nil
      parsed_body = JSON.parse(request.raw_post)
      form_data = parsed_body['form']

      raise Common::Exceptions::ParameterMissing, 'form' unless form_data

      # Transform 3-character country codes to 2-character codes for PDF compatibility
      transform_country_codes!(form_data)

      claim = create_claim_from_form_data(form_data)
      pdf_path = generate_and_send_pdf(claim)
    rescue JSON::ParserError
      raise Common::Exceptions::ParameterMissing, 'form'
    ensure
      # Delete the temporary PDF file
      begin
        File.delete(pdf_path) if pdf_path
      rescue Errno::ENOENT
        # Ignore if file doesn't exist
      end
    end

    private

    def transform_country_codes!(form_data)
      # Transform claimant address country code
      claimant_address = form_data.dig('claimantInformation', 'address')
      if claimant_address&.key?('country')
        transformed_country = extract_country(claimant_address)
        claimant_address['country'] = transformed_country if transformed_country
      end

      # Transform hospital address country code
      hospital_address = form_data.dig('additionalInformation', 'hospitalAddress')
      if hospital_address&.key?('country')
        transformed_country = extract_country(hospital_address)
        hospital_address['country'] = transformed_country if transformed_country
      end
    end

    def create_claim_from_form_data(form_data)
      form_body = form_data.to_json
      claim = SavedClaim::Form212680.new(form: form_body)
      raise(Common::Exceptions::ValidationErrors, claim) unless claim.save

      claim
    end

    def generate_and_send_pdf(claim)
      pdf_path = with_retries('Generate 21-2680 PDF') do
        claim.generate_prefilled_pdf
      end
      file_data = File.read(pdf_path)

      send_data file_data,
                filename: "VA_Form_21-2680_#{Time.current.strftime('%Y%m%d_%H%M%S')}.pdf",
                type: 'application/pdf',
                disposition: 'attachment'

      pdf_path
    end

    def check_feature_enabled
      routing_error unless Flipper.enabled?(:form_2680_enabled, current_user)
    end
  end
end
