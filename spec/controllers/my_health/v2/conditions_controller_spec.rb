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
      allow_any_instance_of(UnifiedHealthData::Service).to receive(:get_conditions)
        .and_return(mock_conditions)
    end

    it 'calls service without date parameters' do
      expect_any_instance_of(UnifiedHealthData::Service).to receive(:get_conditions)
        .with(no_args)

      get :index
    end

    it 'returns serialized conditions in correct format' do
      get :index

      expect(response).to have_http_status(:ok)

      json_response = JSON.parse(response.body)
      expect(json_response).to be_an(Array)
      expect(json_response.first).to include(
        'id' => 'condition-1',
        'name' => 'Test Condition',
        'provider' => 'Dr. Test',
        'facility' => 'Test Facility',
        'comments' => 'Test comments'
      )
    end

    it 'executes successfully without logging' do
      get :index
      expect(response).to have_http_status(:ok)
    end
  end
end
