# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/service'

RSpec.describe 'MyHealth::V2::CcdController', type: :request do
  let(:user_id) { '11898795' }
  let(:current_user) { build(:user, :mhv) }
  let(:start_date) { '2024-01-01' }
  let(:end_date) { '2024-12-31' }
  let(:path) { '/my_health/v2/medical_records/ccd/download' }

  let(:binary_data) do
    UnifiedHealthData::BinaryData.new(
      content_type: 'application/xml',
      binary: Base64.strict_encode64('<ClinicalDocument>test</ClinicalDocument>')
    )
  end

  before do
    sign_in_as(current_user)
  end

  describe 'GET /my_health/v2/medical_records/ccd/download' do
    context 'when successful with XML format' do
      before do
        allow_any_instance_of(UnifiedHealthData::Service)
          .to receive(:get_ccd_binary)
          .and_return(binary_data)
      end

      it 'returns XML CCD' do
        get path, params: { start_date:, end_date:, format: 'xml' }

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include('application/xml')
        expect(response.body).to include('<ClinicalDocument>')
      end

      it 'sets correct filename for XML' do
        get path, params: { start_date:, end_date:, format: 'xml' }

        expect(response.headers['Content-Disposition']).to include('filename="ccd.xml"')
      end

      it 'decodes Base64 data correctly' do
        get path, params: { start_date:, end_date:, format: 'xml' }

        expect(response.body).not_to match(%r{^[A-Za-z0-9+/=]+$}) # Not Base64
        expect(response.body).to include('<ClinicalDocument>') # Decoded XML
      end
    end

    context 'when successful with HTML format' do
      let(:html_data) do
        UnifiedHealthData::BinaryData.new(
          content_type: 'text/html',
          binary: Base64.strict_encode64('<html><body>test</body></html>')
        )
      end

      it 'returns HTML CCD' do
        allow_any_instance_of(UnifiedHealthData::Service)
          .to receive(:get_ccd_binary)
          .and_return(html_data)

        get path, params: { start_date:, end_date:, format: 'html' }

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include('text/html')
        expect(response.body).to include('<html>')
      end
    end

    context 'when successful with PDF format' do
      let(:pdf_data) do
        UnifiedHealthData::BinaryData.new(
          content_type: 'application/pdf',
          binary: Base64.strict_encode64('%PDF-1.5')
        )
      end

      it 'returns PDF CCD' do
        allow_any_instance_of(UnifiedHealthData::Service)
          .to receive(:get_ccd_binary)
          .and_return(pdf_data)

        get path, params: { start_date:, end_date:, format: 'pdf' }

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to eq('application/pdf')
      end
    end

    context 'when format is not specified' do
      before do
        allow_any_instance_of(UnifiedHealthData::Service)
          .to receive(:get_ccd_binary)
          .and_return(binary_data)
      end

      it 'defaults to XML format' do
        get path, params: { start_date:, end_date: }

        expect(response).to have_http_status(:ok)
        expect(response.content_type).to include('application/xml')
        expect(response.headers['Content-Disposition']).to include('filename="ccd.xml"')
      end
    end

    context 'when CCD is not found' do
      before do
        allow_any_instance_of(UnifiedHealthData::Service)
          .to receive(:get_ccd_binary)
          .and_return(nil)
      end

      it 'returns 404 not found' do
        get path, params: { start_date:, end_date: }

        expect(response).to have_http_status(:not_found)
        json_response = JSON.parse(response.body)
        expect(json_response['errors'].first['title']).to eq('CCD Not Found')
        expect(json_response['errors'].first['status']).to eq(404)
      end
    end

    context 'when format is invalid' do
      before do
        allow_any_instance_of(UnifiedHealthData::Service)
          .to receive(:get_ccd_binary)
          .and_raise(ArgumentError, 'Invalid format: json. Use xml, html, or pdf')
      end

      it 'returns 400 bad request' do
        get path, params: { start_date:, end_date:, format: 'json' }

        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response['errors'].first['title']).to eq('Invalid Format')
        expect(json_response['errors'].first['detail']).to include('Invalid format')
      end
    end

    context 'when format is unavailable' do
      before do
        allow_any_instance_of(UnifiedHealthData::Service)
          .to receive(:get_ccd_binary)
          .and_raise(ArgumentError, 'Format html not available for this CCD')
      end

      it 'returns 400 bad request' do
        get path, params: { start_date:, end_date:, format: 'html' }

        expect(response).to have_http_status(:bad_request)
        json_response = JSON.parse(response.body)
        expect(json_response['errors'].first['title']).to eq('Invalid Format')
        expect(json_response['errors'].first['detail']).to include('not available')
      end
    end

    context 'when FHIR API error occurs' do
      let(:client_error) do
        Common::Client::Errors::ClientError.new('SCDF service unavailable', 503)
      end

      before do
        allow_any_instance_of(UnifiedHealthData::Service)
          .to receive(:get_ccd_binary)
          .and_raise(client_error)
      end

      it 'returns 502 bad gateway' do
        get path, params: { start_date:, end_date: }

        expect(response).to have_http_status(:bad_gateway)
        json_response = JSON.parse(response.body)
        expect(json_response['errors'].first['title']).to eq('FHIR API Error')
      end
    end

    context 'when unexpected error occurs' do
      before do
        allow_any_instance_of(UnifiedHealthData::Service)
          .to receive(:get_ccd_binary)
          .and_raise(StandardError, 'Unexpected error')
      end

      it 'returns 500 internal server error' do
        get path, params: { start_date:, end_date: }

        expect(response).to have_http_status(:internal_server_error)
        json_response = JSON.parse(response.body)
        expect(json_response['errors'].first['title']).to eq('Internal Server Error')
        expect(json_response['errors'].first['detail']).to include('unexpected error')
      end
    end
  end
end
