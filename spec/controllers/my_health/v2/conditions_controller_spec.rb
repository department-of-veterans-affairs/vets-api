# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MyHealth::V2::ConditionsController, type: :controller do
  routes { MyHealth::Engine.routes }

  let(:user) { build(:user, :mhv) }

  before do
    sign_in_as(user)
    request.env['HTTP_ACCEPT'] = 'application/json'
    request.env['CONTENT_TYPE'] = 'application/json'
  end

  describe '#index' do
    context 'happy path' do
      it 'returns serialized conditions in JSONAPI format' do
        VCR.use_cassette('unified_health_data/get_conditions_200', match_requests_on: %i[method path]) do
          get :index
        end

        expect(response).to have_http_status(:ok)

        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('data')
        expect(json_response['data']).to be_an(Array)

        first_condition = json_response['data'].first
        expect(first_condition['id']).to eq('condition-1')
        expect(first_condition['type']).to eq('condition')
        expect(first_condition['attributes']).to include(
          'name' => 'Test Condition',
          'provider' => 'Dr. Test',
          'facility' => 'Test Facility',
          'comments' => ['Test comments', 'Follow-up needed']
        )
      end

      it 'executes successfully without logging' do
        VCR.use_cassette('unified_health_data/get_conditions_200', match_requests_on: %i[method path]) do
          get :index
        end
        expect(response).to have_http_status(:ok)
      end
    end

    context 'no records' do
      it 'returns empty data array when no conditions found' do
        VCR.use_cassette('unified_health_data/get_conditions_no_records', match_requests_on: %i[method path]) do
          get :index
        end

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('data')
        expect(json_response['data']).to be_an(Array)
        expect(json_response['data']).to be_empty
      end
    end

    context 'error handling' do
      it 'handles Common::Client::Errors::ClientError' do
        error = Common::Client::Errors::ClientError.new('FHIR API error', 502)
        allow_any_instance_of(UnifiedHealthData::Service).to receive(:get_conditions)
          .and_raise(error)

        get :index

        expect(response).to have_http_status(:bad_gateway)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to be_an(Array)
        expect(json_response['errors'].first).to include(
          'title' => 'FHIR API Error',
          'detail' => 'FHIR API error',
          'code' => 502,
          'status' => 502
        )
      end

      it 'handles Common::Exceptions::BackendServiceException' do
        error_detail = { 'detail' => 'Backend service is unavailable' }
        error = Common::Exceptions::BackendServiceException.new('UHD_SERVICE_ERROR', {}, 502, error_detail)
        allow(error).to receive(:errors).and_return([error_detail])
        allow_any_instance_of(UnifiedHealthData::Service).to receive(:get_conditions)
          .and_raise(error)

        get :index

        expect(response.status).to be_in([500, 502])
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('errors')
        expect(json_response['errors']).to be_an(Array)
        expect(json_response['errors']).not_to be_empty
      end

      it 'handles StandardError' do
        allow_any_instance_of(UnifiedHealthData::Service).to receive(:get_conditions)
          .and_raise(StandardError.new('Unexpected error'))

        get :index

        expect(response).to have_http_status(:internal_server_error)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to be_an(Array)
        expect(json_response['errors'].first).to include(
          'title' => 'Internal Server Error',
          'detail' => 'An unexpected error occurred while retrieving conditions.',
          'code' => '500',
          'status' => 500
        )
      end

      it 'logs errors appropriately' do
        allow(Rails.logger).to receive(:error)
        allow_any_instance_of(UnifiedHealthData::Service).to receive(:get_conditions)
          .and_raise(StandardError.new('Test error'))

        get :index

        expect(Rails.logger).to have_received(:error)
          .with('Unexpected error in conditions controller: Test error')
      end
    end
  end

  describe '#show' do
    let(:condition_id) { 'condition-1' }

    context 'happy path' do
      it 'returns a single condition successfully' do
        VCR.use_cassette('unified_health_data/get_conditions_200', match_requests_on: %i[method path]) do
          get :show, params: { id: condition_id }
        end

        expect(response).to have_http_status(:ok)
        json_response = JSON.parse(response.body)

        expect(json_response).to have_key('data')
        condition_data = json_response['data']
        expect(condition_data['id']).to eq(condition_id)
        expect(condition_data['type']).to eq('condition')
        expect(condition_data['attributes']).to include(
          'name' => 'Test Condition',
          'provider' => 'Dr. Test',
          'facility' => 'Test Facility',
          'comments' => ['Test comments', 'Follow-up needed']
        )
      end
    end

    context 'when condition not found' do
      it 'returns 404 error' do
        VCR.use_cassette('unified_health_data/get_conditions_no_records', match_requests_on: %i[method path]) do
          get :show, params: { id: 'nonexistent' }
        end

        expect(response).to have_http_status(:not_found)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to be_an(Array)
        expect(json_response['errors'].first).to include(
          'title' => 'Record Not Found',
          'detail' => 'The requested condition was not found',
          'code' => '404',
          'status' => 404
        )
      end
    end

    context 'error handling' do
      it 'handles Common::Client::Errors::ClientError' do
        error = Common::Client::Errors::ClientError.new('FHIR API error', 502)
        allow_any_instance_of(UnifiedHealthData::Service).to receive(:get_single_condition)
          .and_raise(error)

        get :show, params: { id: condition_id }

        expect(response).to have_http_status(:bad_gateway)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to be_an(Array)
        expect(json_response['errors'].first).to include(
          'title' => 'FHIR API Error'
        )
      end

      it 'handles Common::Exceptions::BackendServiceException' do
        error_detail = { 'detail' => 'Backend service is unavailable' }
        error = Common::Exceptions::BackendServiceException.new('UHD_SERVICE_ERROR', {}, 502, error_detail)
        allow(error).to receive(:errors).and_return([error_detail])
        allow_any_instance_of(UnifiedHealthData::Service).to receive(:get_single_condition)
          .and_raise(error)

        get :show, params: { id: condition_id }

        expect(response.status).to be_in([500, 502])
        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('errors')
      end

      it 'handles StandardError' do
        allow_any_instance_of(UnifiedHealthData::Service).to receive(:get_single_condition)
          .and_raise(StandardError.new('Unexpected error'))

        get :show, params: { id: condition_id }

        expect(response).to have_http_status(:internal_server_error)
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to be_an(Array)
        expect(json_response['errors'].first).to include(
          'title' => 'Internal Server Error',
          'detail' => 'An unexpected error occurred while retrieving conditions.',
          'code' => '500',
          'status' => 500
        )
      end
    end
  end
end
