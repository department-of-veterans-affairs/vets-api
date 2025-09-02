# frozen_string_literal: true

require 'rails_helper'
require 'support/mr_client_helpers'
require 'medical_records/client'
require 'medical_records/bb_internal/client'
require 'support/shared_examples_for_mhv'
require 'unified_health_data/service'

RSpec.describe 'MyHealth::V2::ConditionsController', :skip_json_api_validation, type: :request do
  let(:user_id) { '11898795' }

  let(:path) { '/my_health/v2/medical_records/conditions' }
  let(:current_user) { build(:user, :mhv) }

  let(:mock_conditions) do
    [
      UnifiedHealthData::Condition.new(
        id: 'condition-1',
        date: '2025-01-15T10:30:00Z',
        name: 'Essential hypertension',
        provider: 'Dr. Smith, John',
        facility: 'VA Medical Center',
        comments: ['Well-controlled with medication.', 'Patient adherent to treatment plan.']
      ),
      UnifiedHealthData::Condition.new(
        id: 'condition-2',
        date: nil,
        name: 'Major depressive disorder, recurrent, moderate',
        provider: 'BORLAND,VICTORIA A',
        facility: 'CHYSHR TEST LAB',
        comments: []
      )
    ]
  end

  before do
    sign_in_as(current_user)
  end

  describe 'GET /my_health/v2/medical_records/conditions' do
    context 'happy path' do
      before do
        allow_any_instance_of(UnifiedHealthData::Service).to receive(:get_conditions)
          .and_return(mock_conditions)

        get path, headers: { 'X-Key-Inflection' => 'camel' }
      end

      it 'returns a successful response' do
        expect(response).to be_successful
      end

      it 'returns conditions data in JSONAPI format', :aggregate_failures do
        json_response = JSON.parse(response.body)
        expect(json_response).to be_an(Array)
        expect(json_response.size).to eq(2)

        # Test first condition (with date)
        first_condition = json_response.first
        expect(first_condition['id']).to eq('condition-1')
        expect(first_condition['type']).to eq('condition')
        expect(first_condition['attributes']).to include(
          'date' => '2025-01-15T10:30:00Z',
          'name' => 'Essential hypertension',
          'provider' => 'Dr. Smith, John',
          'facility' => 'VA Medical Center',
          'comments' => ['Well-controlled with medication.', 'Patient adherent to treatment plan.']
        )

        # Test second condition (with null date)
        second_condition = json_response[1]
        expect(second_condition['id']).to eq('condition-2')
        expect(second_condition['type']).to eq('condition')
        expect(second_condition['attributes']).to include(
          'date' => nil, # This tests our null date handling
          'name' => 'Major depressive disorder, recurrent, moderate',
          'provider' => 'BORLAND,VICTORIA A',
          'facility' => 'CHYSHR TEST LAB',
          'comments' => []
        )
      end
    end
  end
end
