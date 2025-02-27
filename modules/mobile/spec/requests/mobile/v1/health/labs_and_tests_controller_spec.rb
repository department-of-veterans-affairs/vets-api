# frozen_string_literal: true

require 'rails_helper'

require_relative '../../../../support/helpers/rails_helper'
require_relative '../../../../support/helpers/committee_helper'

RSpec.describe 'Mobile::V1::LabsAndTestsController', :skip_json_api_validation, type: :request do
  include JsonSchemaMatchers
  include CommitteeHelper

  let!(:user) { sis_user(icn: '1000000000V000000') }
  let(:default_params) { { 'patient-id': '1000000000V000000', start_date: '2024-01-01', end_date: '2024-12-31' } }
  let(:path) { '/mobile/v1/health/labs-and-tests' }
  let(:labs_cassette) { 'mobile/unified_health_data/get_labs' }
  let(:uhd_flipper) { :mhv_accelerated_delivery_uhd_enabled }
  let(:sp_flipper) { :mhv_accelerated_delivery_uhd_sp_enabled }
  let(:expected_response) do
    JSON.parse(Rails.root.join(
      'modules', 'mobile', 'spec', 'support', 'fixtures', 'labs_and_tests_response.json'
    ).read)
  end

  describe 'GET /mobile/v1/health/labs-and-tests' do
    context 'happy path' do
      before do
        allow(Flipper).to receive(:enabled?).with(uhd_flipper, instance_of(User)).and_return(true)
        allow(Flipper).to receive(:enabled?).with(sp_flipper, instance_of(User)).and_return(true)
        VCR.use_cassette(labs_cassette) do
          get path, headers: sis_headers, params: default_params
        end
      end

      it 'returns a successful response' do
        expect(response).to be_successful
      end

      it 'returns the correct medical records' do
        json_response = JSON.parse(response.body)
        expect(json_response.count).to eq(1)
        expect(json_response[0]).to eq(expected_response)
      end
    end

    context 'when UHD is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(uhd_flipper, instance_of(User)).and_return(false)
        VCR.use_cassette(labs_cassette) do
          get path, headers: sis_headers, params: default_params
        end
      end

      it 'returns a 500 when the flipper is disabled' do
        expect(response).to have_http_status(:internal_server_error)
      end
    end
  end
end
