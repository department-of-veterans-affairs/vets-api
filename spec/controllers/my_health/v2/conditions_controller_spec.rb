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
          type: 'Condition',
          attributes: UnifiedHealthData::ConditionAttributes.new(
            date: '2025-01-15T10:30:00Z',
            name: 'Test Condition',
            provider: 'Dr. Test',
            facility: 'Test Facility',
            comments: 'Test comments'
          )
        )
      ]
    end

    before do
      allow_any_instance_of(UnifiedHealthData::ConditionService).to receive(:get_conditions)
        .and_return(mock_conditions)
    end

    it 'calls service without date parameters' do
      expect_any_instance_of(UnifiedHealthData::ConditionService).to receive(:get_conditions)
        .with(no_args)

      get :index
    end

    it 'returns serialized conditions in correct format' do
      get :index

      expect(response).to have_http_status(:ok)

      json_response = JSON.parse(response.body)
      expect(json_response).to have_key('data')
      expect(json_response['data']).to be_an(Array)
      expect(json_response['data'].first).to include(
        'id' => 'condition-1',
        'name' => 'Test Condition',
        'provider' => 'Dr. Test',
        'facility' => 'Test Facility',
        'comments' => 'Test comments'
      )
    end

    it 'logs request information' do
      expect(Rails.logger).to receive(:info).with(hash_including(
                                                    message: 'Fetching conditions for user',
                                                    feature: 'conditions_v2'
                                                  ))

      expect(Rails.logger).to receive(:info).with(hash_including(
                                                    message: 'Successfully fetched conditions',
                                                    feature: 'conditions_v2',
                                                    result_count: 1
                                                  ))

      get :index
    end

    it 'tracks metrics' do
      expect(StatsD).to receive(:gauge).with('api.my_health.conditions_v2.count', 1)

      get :index
    end
  end

  context 'when service raises ClientError' do
    before do
      allow_any_instance_of(UnifiedHealthData::ConditionService).to receive(:get_conditions)
        .and_raise(Common::Client::Errors::ClientError.new('FHIR Error', 502))
    end

    it 'handles error and returns appropriate response' do
      expect(Rails.logger).to receive(:error).with(hash_including(
                                                     message: 'Conditions FHIR API error: FHIR Error',
                                                     feature: 'conditions_v2'
                                                   ))

      get :index

      expect(response).to have_http_status(:bad_gateway)

      json_response = JSON.parse(response.body)
      expect(json_response['errors'].first).to include(
        'title' => 'FHIR API Error',
        'detail' => 'FHIR Error'
      )
    end
  end

  context 'when service raises StandardError' do
    before do
      allow_any_instance_of(UnifiedHealthData::ConditionService).to receive(:get_conditions)
        .and_raise(StandardError.new('Unexpected error'))
    end

    it 'handles generic errors' do
      expect(Rails.logger).to receive(:error).with(hash_including(
                                                     message: 'Unexpected error in conditions v2 controller: Error',
                                                     feature: 'conditions_v2'
                                                   ))

      get :index

      expect(response).to have_http_status(:internal_server_error)

      json_response = JSON.parse(response.body)
      expect(json_response['errors'].first).to include(
        'title' => 'Internal Server Error',
        'detail' => 'An unexpected error occurred while retrieving condition records'
      )
    end
  end

  context 'returns all results for client-side pagination' do
    it 'returns all conditions without date filtering' do
      expect_any_instance_of(UnifiedHealthData::ConditionService).to receive(:get_conditions)
        .with(no_args)
        .and_return([])

      get :index
    end
  end
end
