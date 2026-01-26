# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V0::Profile::SchedulingPreferences', type: :request do
  include SchemaMatchers

  let(:user) { build(:user, :loa3) }
  let(:headers) { { 'Content-Type' => 'application/json', 'Accept' => 'application/json' } }

  before do
    allow(Flipper).to receive(:enabled?).with(:profile_scheduling_preferences, user).and_return(true)
    allow_any_instance_of(UserVisnService).to receive(:in_pilot_visn?).and_return(true)

    service_response_mock = double(
      status: 200,
      person_options: [],
      bio: { personOptions: [] }
    )

    allow_any_instance_of(VAProfile::PersonSettings::Service).to receive(:get_person_options)
      .and_return(service_response_mock)
    allow_any_instance_of(VAProfile::PersonSettings::Service).to receive(:update_person_options)
      .and_return(double)

    transaction_mock = double(
      id: 'txn-123',
      transaction_id: 'txn-123',
      transaction_status: 'RECEIVED',
      type: 'AsyncTransaction::VAProfile::PersonOptionsTransaction'
    )

    allow(AsyncTransaction::VAProfile::PersonOptionsTransaction).to receive(:start)
      .and_return(transaction_mock)

    allow_any_instance_of(AsyncTransaction::BaseSerializer).to receive(:serializable_hash)
      .and_return({
                    data: {
                      id: 'txn-123',
                      type: 'async_transaction_va_profile_person_options_transactions',
                      attributes: {
                        transaction_id: 'txn-123',
                        transaction_status: 'RECEIVED',
                        type: 'AsyncTransaction::VAProfile::PersonOptionsTransaction',
                        metadata: []
                      }
                    }
                  })
  end

  describe 'GET /v0/profile/scheduling_preferences' do
    context 'with a 200 response' do
      before { sign_in_as(user) }

      it 'returns scheduling preferences', :aggregate_failures do
        get('/v0/profile/scheduling_preferences', headers:)

        expect(response).to have_http_status(:ok)
        expect(response).to match_response_schema('scheduling_preferences')
      end
    end

    context 'with a 401 response' do
      it 'returns unauthorized' do
        get('/v0/profile/scheduling_preferences', headers:)
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'with a 403 response' do
      before do
        sign_in_as(user)
        allow_any_instance_of(UserVisnService).to receive(:in_pilot_visn?)
          .and_return(false)
      end

      it 'returns forbidden when user not in pilot VISN' do
        get('/v0/profile/scheduling_preferences', headers:)
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe 'POST /v0/profile/scheduling_preferences' do
    let(:scheduling_preferences) { { item_id: 1, option_ids: [5] } }

    context 'with a 200 response' do
      before { sign_in_as(user) }

      it 'creates scheduling preferences and returns transaction', :aggregate_failures do
        post('/v0/profile/scheduling_preferences', params: scheduling_preferences.to_json, headers:)

        expect(response).to have_http_status(:ok)
        expect(response).to match_response_schema('va_profile/transaction_response')
      end
    end

    context 'with a 401 response' do
      it 'returns unauthorized' do
        post('/v0/profile/scheduling_preferences', params: scheduling_preferences.to_json, headers:)
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'PUT /v0/profile/scheduling_preferences' do
    let(:scheduling_preferences) { { item_id: 1, option_ids: [7] } }

    context 'with a 200 response' do
      before { sign_in_as(user) }

      it 'updates scheduling preferences and returns transaction', :aggregate_failures do
        put('/v0/profile/scheduling_preferences', params: scheduling_preferences.to_json, headers:)

        expect(response).to have_http_status(:ok)
        expect(response).to match_response_schema('va_profile/transaction_response')
      end
    end

    context 'with a 401 response' do
      it 'returns unauthorized' do
        put('/v0/profile/scheduling_preferences', params: scheduling_preferences.to_json, headers:)
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /v0/profile/scheduling_preferences' do
    let(:scheduling_preferences) { { item_id: 1, option_ids: [5] } }

    context 'with a 200 response' do
      before { sign_in_as(user) }

      it 'deletes scheduling preferences and returns transaction', :aggregate_failures do
        delete('/v0/profile/scheduling_preferences', params: scheduling_preferences.to_json, headers:)

        expect(response).to have_http_status(:ok)
        expect(response).to match_response_schema('va_profile/transaction_response')
      end
    end

    context 'with a 401 response' do
      it 'returns unauthorized' do
        delete('/v0/profile/scheduling_preferences', params: scheduling_preferences.to_json, headers:)
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end
end
