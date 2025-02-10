# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::UserActionEventsController, type: :controller do
  include RequestHelper

  context 'when not logged in' do
    it 'returns unauthorized' do
      get :index
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe 'GET #index' do
    let(:idme_uuid) { 'some-idme-uuid' }
    let(:user) { create(:user, idme_uuid:) }
    let!(:user_verification) { create(:idme_user_verification, idme_uuid:) }

    before do
      sign_in_as(user)
    end

    context 'when there are user actions' do
      let(:user_action_event_one) { create(:user_action_event, details: 'Sample event 1') }
      let(:user_action_event_two) { create(:user_action_event, details: 'Sample event 2') }

      let!(:user_action_one) do
        create(:user_action, subject_user_verification_id: user_verification.id,
                             user_action_event: user_action_event_one, created_at: 2.days.ago)
      end
      let!(:user_action_two) do
        create(:user_action, subject_user_verification_id: user_verification.id,
                             user_action_event: user_action_event_two, created_at: 1.day.ago)
      end
      let!(:user_action_three) do
        create(:user_action, subject_user_verification_id: user_verification.id,
                             user_action_event: user_action_event_one, created_at: 5.days.ago)
      end

      let(:page) { 1 }
      let(:per_page) { 4 }

      it 'returns a successful response' do
        get :index, params: { start_date: 1.month.ago.to_date, end_date: Time.zone.now }
        expect(response).to have_http_status(:success)
      end

      it 'filters user actions based on the date range' do
        create(:user_action,
               created_at: 2.days.ago,
               subject_user_verification_id: user_verification.id,
               user_action_event: user_action_event_one)
        create(:user_action,
               created_at: 1.day.ago,
               subject_user_verification_id: user_verification.id,
               user_action_event: user_action_event_two)
        create(:user_action,
               created_at: 5.days.ago,
               subject_user_verification_id: user_verification.id,
               user_action_event: user_action_event_one)

        get :index, params: { start_date: 3.days.ago.to_date, end_date: Time.zone.now }

        expect(response).to have_http_status(:success)

        json_response = JSON.parse(response.body)
        puts json_response.length
        expect(json_response.length).to eq(4)
        expect(json_response.first['user_action_event']['details']).to eq('Sample event 2')
        expect(json_response.third['user_action_event']['details']).to eq('Sample event 1')
      end
    end
  end
end
