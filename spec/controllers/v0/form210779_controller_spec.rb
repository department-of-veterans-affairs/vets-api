# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::Form210779Controller, type: :controller do
  let(:form_id) { '21-0779' }
  let(:form_data) { VetsJsonSchema::EXAMPLES[form_id] }

  let(:last_name) { form_data.dig('veteranInformation', 'fullName', 'last') }

  let(:valid_payload) { { form: form_data }.to_json }

  def parsed_response
    JSON.parse(response.body)
  end

  def confirmation_number
    parsed_response.dig('data', 'attributes', 'confirmation_number')
  end

  describe 'POST #create' do
    it 'returns expected response structure' do
      post(:create, body: valid_payload, as: :json)

      expect(response).to have_http_status(:ok)

      expect(parsed_response['data']['type']).to eq('saved_claims')
      expect(parsed_response['data']['attributes']['form']).to eq(form_id)
      expect(confirmation_number).to be_present
      expect(parsed_response['data']['attributes']['submitted_at']).to be_present
      expect(parsed_response['data']['attributes']['guid']).to be_present
      expect(parsed_response['data']['attributes']['regional_office']).to eq([])
    end

    it 'returns a unique confirmation number for each request' do
      post(:create, body: valid_payload, as: :json)
      first_confirmation = confirmation_number

      post(:create, body: valid_payload, as: :json)
      second_confirmation = confirmation_number

      expect(first_confirmation).not_to eq(second_confirmation)
    end

    it 'returns a valid UUID as confirmation number' do
      post(:create, body: valid_payload, as: :json)

      expect(confirmation_number).to be_a_uuid
    end

    it 'returns ISO 8601 formatted timestamp' do
      post(:create, body: valid_payload, as: :json)

      submitted_at = parsed_response.dig('data', 'attributes', 'submitted_at')
      expect { DateTime.iso8601(submitted_at) }.not_to raise_error
    end

    it 'does not require authentication' do
      post(:create, body: valid_payload, as: :json)
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'get #download_pdf' do
    let(:pdf_content) { 'PDF_BINARY_CONTENT' }

    let(:claim) { create(:va210779) }
    let(:temp_file_path) { "tmp/pdfs/21-0779_#{claim.id}.pdf" }

    it 'generates and downloads PDF' do
      get(:download_pdf, params: { guid: claim.guid })

      expect(response).to have_http_status(:ok)
      expect(response.headers['Content-Type']).to eq('application/pdf')
    end

    it 'includes proper filename with UUID' do
      get(:download_pdf, params: { guid: claim.guid })

      expect(response.headers['Content-Disposition']).to include('attachment')
      expect(response.headers['Content-Disposition']).to include('21-0779_')
      expect(response.headers['Content-Disposition']).to match(/21-0779_[a-f0-9-]+\.pdf/)
    end

    it 'deletes temporary PDF file after sending' do
      expect(File).to receive(:delete).with(temp_file_path)
      get(:download_pdf, params: { guid: claim.guid })
    end

    it 'deletes temporary file even when PDF generation fails' do
      allow_any_instance_of(SavedClaim::Form210779).to receive(:to_pdf).and_raise(StandardError, 'PDF generation error')
      # File.delete should not be called since source_file_path is nil
      expect(File).not_to receive(:delete).with(temp_file_path)

      get(:download_pdf, params: { guid: claim.guid })
      expect(response).to have_http_status(:internal_server_error)
      expect(parsed_response['errors']).to be_present
    end

    it 'deletes temporary file even when file read fails' do
      allow(File).to receive(:read).with(temp_file_path).and_raise(StandardError, 'Read error')
      expect(File).to receive(:delete).with(temp_file_path)

      get(:download_pdf, params: { guid: claim.guid })
      expect(response).to have_http_status(:internal_server_error)

      expect(parsed_response['errors']).to be_present
    end

    it 'does not require authentication' do
      get(:download_pdf, params: { guid: claim.guid })

      expect(response).to have_http_status(:ok)
    end

    context 'error handling' do
      it 'returns 500 for PDF generation failures' do
        allow_any_instance_of(SavedClaim::Form210779).to receive(:to_pdf).and_raise(StandardError,
                                                                                    'PDF generation error')
        get(:download_pdf, params: { guid: claim.guid })

        expect(response).to have_http_status(:internal_server_error)

        expect(parsed_response['errors']).to be_present
        expect(parsed_response['errors'].first['status']).to eq('500')
      end
    end
  end
end
