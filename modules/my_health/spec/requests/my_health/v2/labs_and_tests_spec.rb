# frozen_string_literal: true

require 'rails_helper'
require 'support/mr_client_helpers'
require 'medical_records/client'
require 'medical_records/bb_internal/client'
require 'support/shared_examples_for_mhv'

RSpec.describe 'MyHealth::V2::LabsAndTestsController', :skip_json_api_validation, type: :request do
  let(:user_id) { '11898795' }
  let(:default_params) { { start_date: '2024-01-01', end_date: '2025-05-31' } }
  let(:path) { '/my_health/v2/medical_records/labs_and_tests' }
  let(:labs_cassette) { 'mobile/unified_health_data/get_labs' }
  let(:labs_attachment_cassette) { 'mobile/unified_health_data/get_labs_value_attachment' }
  let(:ch_flipper) { :mhv_accelerated_delivery_uhd_ch_enabled }
  let(:ch_response) do
    JSON.parse(Rails.root.join(
      'modules', 'mobile', 'spec', 'support', 'fixtures', 'labs_and_tests_ch_response.json'
    ).read)
  end
  let(:sp_flipper) { :mhv_accelerated_delivery_uhd_sp_enabled }
  let(:sp_response) do
    JSON.parse(Rails.root.join(
      'modules', 'mobile', 'spec', 'support', 'fixtures', 'labs_and_tests_sp_response.json'
    ).read)
  end
  let(:va_patient) { true }
  let(:current_user) { build(:user, :mhv) }

  before do
    sign_in_as(current_user)
  end

  describe 'GET /mobile/v1/health/labs-and-tests' do
    context 'happy path' do
      before do
        allow(Flipper).to receive(:enabled?).with(ch_flipper, instance_of(User)).and_return(true)
        allow(Flipper).to receive(:enabled?).with(sp_flipper, instance_of(User)).and_return(true)
        VCR.use_cassette(labs_cassette) do
          get path, headers: { 'X-Key-Inflection' => 'camel' }, params: default_params
        end
      end

      it 'returns a successful response' do
        expect(response).to be_successful
      end

      it 'returns the correct lab records' do
        json_response = JSON.parse(response.body)
        expect(json_response.count).to eq(4)
        expect(json_response[1]).to eq(ch_response)
        expect(json_response[3]).to eq(sp_response)
      end
    end

    context 'errors' do
      before do
        allow(Flipper).to receive(:enabled?).with(ch_flipper, instance_of(User)).and_return(true)
        allow(Flipper).to receive(:enabled?).with(sp_flipper, instance_of(User)).and_return(true)
        allow(Rails.logger).to receive(:error)
        VCR.use_cassette(labs_attachment_cassette) do
          get path, headers: { 'X-Key-Inflection' => 'camel' }, params: default_params
        end
      end

      it 'returns not_implemented when a value attachment is received' do
        expect(Rails.logger).to have_received(:error).with(
          { message: 'Observation with ID 4e0a8d43-1281-4d11-97b8-f77452bea53a has unsupported value type: Attachment' }
        )
        expect(response).to have_http_status(:not_implemented)
      end
    end
  end
end
