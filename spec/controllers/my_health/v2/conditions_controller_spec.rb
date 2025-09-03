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
    let(:mock_conditions) do
      [
        UnifiedHealthData::Condition.new(
          id: 'condition-1',
          date: '2025-01-15T10:30:00Z',
          name: 'Test Condition',
          provider: 'Dr. Test',
          facility: 'Test Facility',
          comments: ['Test comments', 'Follow-up needed']
        )
      ]
    end

    before do
      allow_any_instance_of(UnifiedHealthData::Service).to receive(:get_conditions)
        .and_return(mock_conditions)
    end

    it 'calls service without date parameters' do
      expect_any_instance_of(UnifiedHealthData::Service).to receive(:get_conditions)
        .with(no_args)

      get :index
    end

    it 'returns serialized conditions in JSONAPI format' do
      get :index

      expect(response).to have_http_status(:ok)

      json_response = JSON.parse(response.body)
      expect(json_response).to be_an(Array)

      first_condition = json_response.first
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
      get :index
      expect(response).to have_http_status(:ok)
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
end
