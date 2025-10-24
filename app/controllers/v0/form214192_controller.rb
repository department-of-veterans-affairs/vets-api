# frozen_string_literal: true

# Temporary stub implementation for Form 21-4192 to enable parallel frontend development
# This entire file will be replaced with the full implementation in Phase 1

module V0
  class Form214192Controller < ApplicationController
    service_tag 'employment-information'
    skip_before_action :authenticate, only: %i[create download_pdf]
    skip_before_action :verify_authenticity_token

    def create
      confirmation_number = SecureRandom.uuid
      submitted_at = Time.current

      render json: {
        data: {
          id: '12345',
          type: 'saved_claims',
          attributes: {
            submitted_at: submitted_at.iso8601,
            regional_office: [],
            confirmation_number:,
            guid: confirmation_number,
            form: '21-4192'
          }
        }
      }, status: :ok
    end

    def download_pdf
      parsed_form = JSON.parse(params[:form])

      source_file_path = PdfFill::Filler.fill_ancillary_form(parsed_form, SecureRandom.uuid, '21-4192')

      client_file_name = "21-4192_#{SecureRandom.uuid}.pdf"

      file_contents = File.read(source_file_path)

      send_data file_contents, filename: client_file_name, type: 'application/pdf', disposition: 'attachment'
    ensure
      File.delete(source_file_path) if source_file_path && File.exist?(source_file_path)
    end
  end
end
