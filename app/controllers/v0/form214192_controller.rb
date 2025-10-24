# frozen_string_literal: true

# Temporary stub implementation for Form 21-4192 to enable parallel frontend development
# This entire file will be replaced with the full implementation in Phase 1

module V0
  class Form214192Controller < ApplicationController
    include RetriableConcern

    service_tag 'employment-information'
    skip_before_action :authenticate, only: %i[create download_pdf]

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
      parsed_form = parse_form_data
      source_file_path = generate_pdf(parsed_form)

      send_pdf_response(source_file_path)
    rescue JSON::ParserError => e
      handle_json_parse_error(e)
    rescue => e
      handle_pdf_generation_error(e)
    ensure
      cleanup_temp_file(source_file_path)
    end

    private

    def parse_form_data
      JSON.parse(params[:form])
    end

    def generate_pdf(parsed_form)
      with_retries('Generate 21-4192 PDF') do
        PdfFill::Filler.fill_ancillary_form(parsed_form, SecureRandom.uuid, '21-4192')
      end
    end

    def send_pdf_response(source_file_path)
      client_file_name = "21-4192_#{SecureRandom.uuid}.pdf"
      file_contents = File.read(source_file_path)
      send_data file_contents, filename: client_file_name, type: 'application/pdf', disposition: 'attachment'
    end

    def handle_json_parse_error(error)
      Rails.logger.error('Form214192: Invalid JSON in form parameter', error: error.message)
      render json: {
        errors: [{
          title: 'Invalid JSON',
          detail: 'The form data provided is not valid JSON',
          status: '400'
        }]
      }, status: :bad_request
    end

    def handle_pdf_generation_error(error)
      Rails.logger.error('Form214192: Error generating PDF', error: error.message, backtrace: error.backtrace)
      render json: {
        errors: [{
          title: 'PDF Generation Failed',
          detail: 'An error occurred while generating the PDF',
          status: '500'
        }]
      }, status: :internal_server_error
    end

    def cleanup_temp_file(file_path)
      File.delete(file_path) if file_path && File.exist?(file_path)
    end
  end
end
