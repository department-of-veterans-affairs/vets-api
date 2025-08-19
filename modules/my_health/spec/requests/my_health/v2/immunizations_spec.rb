# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'MyHealth::V2::ImmunizationsController', :skip_json_api_validation, type: :request do
  let(:default_params) { { start_date: '2015-01-01', end_date: '2015-12-31' } }
  let(:path) { '/my_health/v2/medical_records/immunizations' }
  let(:immunizations_cassette) { 'lighthouse/veterans_health/get_immunizations' }
  let(:current_user) { build(:user, :mhv) }

  before do
    sign_in_as(current_user)
    # Enable the feature toggle by default for most tests
    allow(Flipper).to receive(:enabled?).with(
      :mhv_accelerated_delivery_vaccines_enabled
    ).and_return(true)
  end

  describe 'GET /my_health/v2/medical_records/immunizations' do
    context 'happy path' do
      before do
        VCR.use_cassette(immunizations_cassette) do
          get path, headers: { 'X-Key-Inflection' => 'camel' }, params: default_params
        end
      end

      it 'returns a successful response' do
        expect(response).to be_successful
      end

      context 'when date parameters are not provided' do
        before do
          VCR.use_cassette(immunizations_cassette) do
            get path, headers: { 'X-Key-Inflection' => 'camel' }, params: nil
          end
        end

        it 'returns a successful response' do
          expect(response).to be_successful
        end
      end

      it 'tracks metrics in StatsD with exact immunization count' do
        # First make a request to get the actual JSON response
        VCR.use_cassette(immunizations_cassette) do
          get path, headers: { 'X-Key-Inflection' => 'camel' }, params: default_params
        end

        # Get the actual count of immunizations returned
        json_response = JSON.parse(response.body)
        actual_count = json_response['data'].length

        # Now test that StatsD receives that exact count
        expect(StatsD).to receive(:gauge).with('api.my_health.immunizations.count', actual_count)

        # Make the request again with the mock in place
        VCR.use_cassette(immunizations_cassette) do
          get path, headers: { 'X-Key-Inflection' => 'camel' }, params: default_params
        end
      end

      it 'includes location information in immunization data' do
        json_response = JSON.parse(response.body)

        # Verify that immunizations have location data
        expect(json_response['data']).to be_an(Array)
        expect(json_response['data']).not_to be_empty

        # Check that each immunization includes location data
        json_response['data'].each do |immunization|
          expect(immunization['attributes']).to have_key('location')
          expect(immunization['attributes']).to have_key('locationId')
        end

        # Verify the location name for the first immunization
        expect(json_response['data'][0]['attributes']['location']).to eq('TEST VA FACILITY')
      end
    end

    context 'error cases' do
      let(:mock_client) { instance_double(Lighthouse::VeteransHealth::Client) }

      before do
        allow_any_instance_of(MyHealth::V2::ImmunizationsController).to receive(:client).and_return(mock_client)
      end

      context 'with client error' do
        before do
          allow(mock_client).to receive(:get_immunizations)
            .and_raise(Common::Client::Errors::ClientError.new('FHIR API Error', 500))

          # Expect logger to receive error
          expect(Rails.logger).to receive(:error).with(/Immunizations FHIR API error/)

          get path, headers: { 'X-Key-Inflection' => 'camel' }, params: default_params
        end

        it 'returns bad_gateway status code' do
          expect(response).to have_http_status(:bad_gateway)
        end

        it 'returns formatted error details' do
          json_response = JSON.parse(response.body)
          expect(json_response).to have_key('errors')
          expect(json_response['errors']).to be_an(Array)
          expect(json_response['errors'].first).to include(
            'title' => 'FHIR API Error',
            'detail' => 'FHIR API Error'
          )
        end
      end

      context 'with backend service exception' do
        before do
          allow(mock_client).to receive(:get_immunizations)
            .and_raise(Common::Exceptions::BackendServiceException.new('VA900', detail: 'Backend Service Unavailable'))

          # Expect logger to receive error
          expect(Rails.logger).to receive(:error).with(/Backend service exception/)

          get path, headers: { 'X-Key-Inflection' => 'camel' }, params: default_params
        end

        it 'returns bad_gateway status code' do
          expect(response).to have_http_status(:bad_gateway)
        end

        it 'includes error details in the response' do
          json_response = JSON.parse(response.body)
          expect(json_response).to have_key('errors')
        end
      end

      context 'when response has no entries' do
        before do
          empty_response = { 'resourceType' => 'Bundle', 'entry' => [] }
          allow(mock_client).to receive(:get_immunizations)
            .and_return(OpenStruct.new(body: empty_response))

          # Expect StatsD to receive count of 0
          expect(StatsD).to receive(:gauge).with('api.my_health.immunizations.count', 0)

          get path, headers: { 'X-Key-Inflection' => 'camel' }, params: default_params
        end

        it 'returns a successful response' do
          expect(response).to be_successful
        end

        it 'returns an empty data array' do
          json_response = JSON.parse(response.body)
          expect(json_response['data']).to eq([])
        end
      end
    end

    context 'when feature toggle is disabled' do
      before do
        # Override the default and disable the feature toggle
        allow(Flipper).to receive(:enabled?).with(
          :mhv_accelerated_delivery_vaccines_enabled
        ).and_return(false)

        get path, headers: { 'X-Key-Inflection' => 'camel' }, params: default_params
      end

      it 'returns forbidden status' do
        expect(response).to have_http_status(:forbidden)
      end

      it 'returns appropriate error message' do
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('errors')
        expect(json_response['errors'].first).to include(
          'title' => 'Feature Disabled',
          'detail' => 'The immunizations feature is currently disabled'
        )
      end
    end
  end

  describe 'GET /my_health/v2/medical_records/immunizations/:id' do
    let(:immunization_id) { '4-NsaRGtyJ4oKq' }
    let(:show_path) { "#{path}/#{immunization_id}" }
    let(:show_params) { default_params }

    context 'happy path' do
      before do
        VCR.use_cassette(immunizations_cassette) do
          get show_path, headers: { 'X-Key-Inflection' => 'camel' }, params: show_params
        end
      end

      it 'returns a successful response' do
        expect(response).to be_successful
        json_response = JSON.parse(response.body)

        expect(json_response['data']).to be_a(Hash)
        expect(json_response['data']['id']).to eq(immunization_id)
        expect(json_response['data']['type']).to eq('immunization')
        expect(json_response['data']['attributes']).to have_key('location')
      end
    end

    context 'when the date parameters are not provided' do
      before do
        VCR.use_cassette(immunizations_cassette) do
          get show_path, headers: { 'X-Key-Inflection' => 'camel' }
        end
      end

      it 'returns a successful response' do
        expect(response).to be_successful
        json_response = JSON.parse(response.body)

        expect(json_response['data']).to be_a(Hash)
        expect(json_response['data']['id']).to eq(immunization_id)
        expect(json_response['data']['type']).to eq('immunization')
        expect(json_response['data']['attributes']).to have_key('location')
      end
    end

    context 'error cases' do
      let(:mock_client) { instance_double(Lighthouse::VeteransHealth::Client) }

      before do
        allow_any_instance_of(MyHealth::V2::ImmunizationsController).to receive(:client).and_return(mock_client)
      end

      context 'with client error' do
        before do
          allow(mock_client).to receive(:get_immunizations)
            .and_raise(Common::Client::Errors::ClientError.new('FHIR API Error', 500))

          # Expect logger to receive error
          expect(Rails.logger).to receive(:error).with(/Immunizations FHIR API error/)

          get show_path, headers: { 'X-Key-Inflection' => 'camel' }, params: show_params
        end

        it 'returns bad_gateway status code' do
          expect(response).to have_http_status(:bad_gateway)
        end

        it 'returns formatted error details' do
          json_response = JSON.parse(response.body)
          expect(json_response).to have_key('errors')
          expect(json_response['errors']).to be_an(Array)
          expect(json_response['errors'].first).to include(
            'title' => 'FHIR API Error',
            'detail' => 'FHIR API Error'
          )
        end
      end

      context 'with backend service exception' do
        before do
          allow(mock_client).to receive(:get_immunizations)
            .and_raise(Common::Exceptions::BackendServiceException.new('VA900', detail: 'Backend Service Unavailable'))

          # Expect logger to receive error
          expect(Rails.logger).to receive(:error).with(/Backend service exception/)

          get show_path, headers: { 'X-Key-Inflection' => 'camel' }, params: show_params
        end

        it 'returns bad_gateway status code' do
          expect(response).to have_http_status(:bad_gateway)
        end

        it 'includes error details in the response' do
          json_response = JSON.parse(response.body)
          expect(json_response).to have_key('errors')
        end
      end

      context 'when immunization not found' do
        before do
          allow(mock_client).to receive(:get_immunizations)
            .and_raise(Common::Client::Errors::ClientError.new('Not Found', 404))

          # Expect logger to receive error
          expect(Rails.logger).to receive(:error).with(/Immunization not found/)
        end
      end
    end
  end
end
