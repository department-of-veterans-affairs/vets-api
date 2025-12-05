# frozen_string_literal: true

require 'rails_helper'
require 'unified_health_data/service'

RSpec.describe 'MyHealth::V2::CcdController', type: :request do
  let(:user_id) { '11898795' }
  let(:current_user) { build(:user, :mhv, icn: '1000123456V123456') }
  let(:path) { '/my_health/v2/medical_records/ccd/download' }
  let(:ccd_cassette) { 'mobile/unified_health_data/get_ccd' }

  before do
    sign_in_as(current_user)
    Timecop.freeze(Time.zone.parse('2025-10-22'))
  end

  after do
    Timecop.return
  end

  describe 'GET /my_health/v2/medical_records/ccd/download' do
    context 'when successful with XML format' do
      it 'returns XML CCD' do
        VCR.use_cassette(ccd_cassette) do
          get "#{path}.xml"

          expect(response).to have_http_status(:ok)
          expect(response.content_type).to include('application/xml')
          expect(response.body).to include('ClinicalDocument')
          expect(response.body).to include('<?xml version')
        end
      end

      it 'sets correct filename for XML' do
        VCR.use_cassette(ccd_cassette) do
          get "#{path}.xml"

          expect(response.headers['Content-Disposition']).to include('filename=ccd.xml')
        end
      end

      it 'decodes Base64 data correctly' do
        VCR.use_cassette(ccd_cassette) do
          get "#{path}.xml"

          expect(response.body).to include('<?xml version') # Decoded XML, not Base64
          expect(response.body).to include('ClinicalDocument')
        end
      end
    end

    context 'when successful with HTML format' do
      it 'returns HTML CCD' do
        VCR.use_cassette(ccd_cassette) do
          get "#{path}.html"

          expect(response).to have_http_status(:ok)
          expect(response.content_type).to include('text/html')
          expect(response.body).to include('<!DOCTYPE html')
        end
      end
    end

    context 'when successful with PDF format' do
      it 'returns PDF CCD' do
        VCR.use_cassette(ccd_cassette) do
          get "#{path}.pdf"

          expect(response).to have_http_status(:ok)
          expect(response.content_type).to eq('application/pdf')
          expect(response.body).to start_with('%PDF')
        end
      end
    end

    context 'when format is not specified' do
      it 'defaults to XML format' do
        VCR.use_cassette(ccd_cassette) do
          get path

          expect(response).to have_http_status(:ok)
          expect(response.content_type).to include('application/xml')
          expect(response.headers['Content-Disposition']).to include('filename=ccd.xml')
        end
      end
    end

    context 'when CCD is not found' do
      let(:service_double) { instance_double(UnifiedHealthData::Service) }

      before do
        allow(UnifiedHealthData::Service).to receive(:new).and_return(service_double)
        allow(service_double).to receive(:get_ccd_binary).and_return(nil)
      end

      it 'returns 404 not found' do
        get path, params: {}

        expect(response).to have_http_status(:not_found)
        json_response = JSON.parse(response.body)
        expect(json_response['errors'].first['title']).to eq('CCD Not Found')
        expect(json_response['errors'].first['status']).to eq(404)
      end
    end

    context 'when format is invalid' do
      it 'returns 404 due to routing constraints (never reaches controller)' do
        get "#{path}.json"

        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when format is unavailable' do
      let(:service_double) { instance_double(UnifiedHealthData::Service) }

      before do
        allow(UnifiedHealthData::Service).to receive(:new).and_return(service_double)
        allow(service_double).to receive(:get_ccd_binary)
          .and_raise(ArgumentError, 'Format html not available for this CCD')
      end

      it 'returns 404 not found' do
        get "#{path}.html"

        expect(response).to have_http_status(:not_found)
        json_response = JSON.parse(response.body)
        expect(json_response['errors'].first['title']).to eq('CCD Format Not Found')
        expect(json_response['errors'].first['detail']).to include('not available')
        expect(json_response['errors'].first['status']).to eq(404)
      end
    end

    context 'when FHIR API error occurs' do
      let(:service_double) { instance_double(UnifiedHealthData::Service) }
      let(:client_error) do
        Common::Client::Errors::ClientError.new('SCDF service unavailable', 503)
      end

      before do
        allow(UnifiedHealthData::Service).to receive(:new).and_return(service_double)
        allow(service_double).to receive(:get_ccd_binary).and_raise(client_error)
      end

      it 'returns correct HTTP status based on error status' do
        get path

        expect(response).to have_http_status(:service_unavailable)
        json_response = JSON.parse(response.body)
        expect(json_response['errors'].first['title']).to eq('FHIR API Error')
      end
    end

    context 'when unexpected error occurs' do
      let(:service_double) { instance_double(UnifiedHealthData::Service) }

      before do
        allow(UnifiedHealthData::Service).to receive(:new).and_return(service_double)
        allow(service_double).to receive(:get_ccd_binary).and_raise(StandardError, 'Unexpected error')
      end

      it 'returns 500 internal server error' do
        get path

        expect(response).to have_http_status(:internal_server_error)
        json_response = JSON.parse(response.body)
        expect(json_response['errors'].first['title']).to eq('Internal Server Error')
        expect(json_response['errors'].first['detail']).to include('unexpected error')
      end
    end
  end
end
