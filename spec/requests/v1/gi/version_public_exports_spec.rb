# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V1::GI::VersionPublicExportsController', type: :request do
  describe 'GET v1/gi/public_exports' do
    let(:service) { GI::LCPE::Client.new(v_client:, lcpe_type:) }

    context 'when export exists' do
      it 'bypasses versioning and returns lacs with 200 response' do
        VCR.use_cassette('gi/public_export_found') do
          get v1_gi_version_public_export_url(id: 'latest')
          expect(response).to have_http_status(:ok)
          expect(response.headers['Content-Type']).to eq('application/x-gzip')
          expect(response.headers['Content-Disposition']).to match(/attachment/)
        end
      end
    end

    context 'when export does not exist' do
      it 'passes through the response' do
        VCR.use_cassette('gi/public_export_missing') do
          get v1_gi_version_public_export_url(id: '1234')
          expect(response).to have_http_status(:not_found)
          expect(response.headers['Content-Type']).to match(%r{application/json})
          expect(JSON.parse(response.body)).to have_key('errors')
        end
      end
    end
  end
end
