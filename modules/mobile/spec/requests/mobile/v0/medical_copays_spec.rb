# frozen_string_literal: true

require_relative '../../../support/helpers/rails_helper'
require_relative '../../../support/helpers/committee_helper'

RSpec.describe 'Mobile::V0::MedicalCopays', type: :request do
  include JsonSchemaMatchers

  let!(:user) { sis_user }

  before do
    allow(Flipper).to receive(:enabled?).with(:mobile_medical_copays_enabled, anything).and_return(true)
  end

  context 'when mobile_medical_copays_enabled feature flag is disabled' do
    before do
      allow(Flipper).to receive(:enabled?).with(:mobile_medical_copays_enabled, anything).and_return(false)
    end

    it 'returns forbidden for index' do
      get '/mobile/v0/medical_copays', headers: sis_headers

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body['error']['code']).to eq('FEATURE_NOT_AVAILABLE')
    end

    it 'returns forbidden for show' do
      get '/mobile/v0/medical_copays/abc123', headers: sis_headers

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body['error']['code']).to eq('FEATURE_NOT_AVAILABLE')
    end

    it 'returns forbidden for download' do
      get '/mobile/v0/medical_copays/download/abc123', headers: sis_headers

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body['error']['code']).to eq('FEATURE_NOT_AVAILABLE')
    end
  end

  describe 'GET medical_copays#index' do
    let(:copays) { { data: [], status: 200 } }

    it 'returns a formatted hash response' do
      allow_any_instance_of(MedicalCopays::VBS::Service).to receive(:get_copays).and_return(copays)

      get '/mobile/v0/medical_copays', headers: sis_headers

      expect(response.body).to match_json_schema('medical_copays')
    end
  end

  describe 'GET medical_copays#show' do
    let(:copay) { { data: { id: 'abc123', details: [], station: {} }, status: 200 } }

    it 'returns a formatted hash response' do
      allow_any_instance_of(MedicalCopays::VBS::Service).to receive(:get_copay_by_id).and_return(copay)

      get '/mobile/v0/medical_copays/abc123', headers: sis_headers

      expect(response.body).to match_json_schema('medical_copay')
    end
  end

  describe 'GET medical_copays#download' do
    describe 'on uncaught exception' do
      it 'returns status 500' do
        allow_any_instance_of(MedicalCopays::VBS::Service).to receive(:get_pdf_statement_by_id).and_raise(StandardError)
        get '/mobile/v0/medical_copays/download/abc123', headers: sis_headers
        expect(response).to have_http_status(:internal_server_error)
      end

      it 'increments statsd failures' do
        allow_any_instance_of(MedicalCopays::VBS::Service).to receive(:get_pdf_statement_by_id).and_raise(StandardError)
        allow(StatsD).to receive(:increment)
        get '/mobile/v0/medical_copays/download/abc123', headers: sis_headers
        expect(StatsD).to have_received(:increment).with('api.mcp.vbs.pdf.failure')
      end
    end

    describe 'on statement not found' do
      it 'returns 404' do
        allow_any_instance_of(MedicalCopays::VBS::Service).to receive(:get_pdf_statement_by_id).and_raise(MedicalCopays::VBS::Service::StatementNotFound)
        get '/mobile/v0/medical_copays/download/abc123', headers: sis_headers
        expect(response).to have_http_status(:not_found)
      end

      it 'increments statsd failures' do
        allow_any_instance_of(MedicalCopays::VBS::Service).to receive(:get_pdf_statement_by_id).and_raise(MedicalCopays::VBS::Service::StatementNotFound)
        allow(StatsD).to receive(:increment)
        get '/mobile/v0/medical_copays/download/abc123', headers: sis_headers
        expect(StatsD).to have_received(:increment).with('api.mcp.vbs.pdf.failure')
      end
    end

    describe 'on success' do
      it 'returns the file contents and headers' do
        pdf_data = 'Sample PDF Contents'
        allow_any_instance_of(MedicalCopays::VBS::Service).to receive(:get_pdf_statement_by_id).and_return(pdf_data)
        get '/mobile/v0/medical_copays/download/abc123', headers: sis_headers,
                                                         params: { file_name: 'sample_file.pdf' }
        expect(response).to have_http_status(:ok)
        expect(response.headers['Content-Type']).to eq('application/pdf')
        expect(response.headers['Content-Disposition']).to include('attachment; filename="sample_file.pdf"')
        expect(response.body).to eq(pdf_data)
      end

      it 'does not increment statsd failures' do
        pdf_data = 'Sample PDF Contents'
        allow_any_instance_of(MedicalCopays::VBS::Service).to receive(:get_pdf_statement_by_id).and_return(pdf_data)
        allow(StatsD).to receive(:increment)
        get '/mobile/v0/medical_copays/download/abc123', headers: sis_headers,
                                                         params: { file_name: 'sample_file.pdf' }
        expect(StatsD).not_to have_received(:increment).with('api.mcp.vbs.pdf.failure')
      end
    end
  end
end
