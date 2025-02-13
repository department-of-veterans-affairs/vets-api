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

      context 'user actions' do
        it 'returns user actions within date range' do
          get :index, params: { start_date: 5.days.ago.to_date, end_date: Time.zone.now }

          json_response = JSON.parse(response.body)
          expect(json_response['data'].length).to eq(3)
        end

        it 'returns user actions by newest to oldest within date range' do
          get :index, params: { start_date: 3.days.ago.to_date, end_date: Time.zone.now }

          json_response = JSON.parse(response.body)
          serialized_user_action = json_response['data'].first
          expect(serialized_user_action['id']).to eq(user_action_two.id)
          expect(serialized_user_action['type']).to eq('user_action')
          expect(serialized_user_action['attributes']['user_action_event_id']).to eq(user_action_event_two.id)
        end

        context 'pagination' do
          it 'paginates the correct number of user actions per page' do
            # page 1
            get :index, params: { start_date: 5.days.ago.to_date, end_date: Time.zone.now, page: 1, per_page: 2 }
            json_response = JSON.parse(response.body)
            expect(json_response['data'].length).to eq(2)

            # page 2
            get :index, params: { start_date: 5.days.ago.to_date, end_date: Time.zone.now, page: 2, per_page: 2 }
            json_response = JSON.parse(response.body)
            expect(json_response['data'].length).to eq(1)
          end

          it 'paginates user actions in order' do
            # page 1
            get :index, params: { start_date: 5.days.ago.to_date, end_date: Time.zone.now, page: 1, per_page: 2 }
            json_response = JSON.parse(response.body)
            expect(json_response['data'].length).to eq(2)
            expect(json_response['data'].first['id']).to eq(user_action_two.id)
            expect(json_response['data'].second['id']).to eq(user_action_one.id)

            # page 2
            get :index, params: { start_date: 5.days.ago.to_date, end_date: Time.zone.now, page: 2, per_page: 2 }
            json_response = JSON.parse(response.body)
            expect(json_response['data'].length).to eq(1)
            expect(json_response['data'].first['id']).to eq(user_action_three.id)
          end
        end
      end

      context 'user action events' do
        it 'returns a successful response' do
          get :index, params: { start_date: 1.month.ago.to_date, end_date: Time.zone.now }
          expect(response).to have_http_status(:success)
        end

        it 'includes the user action event' do
          get :index, params: { start_date: 3.days.ago.to_date, end_date: Time.zone.now }

          expect(response).to have_http_status(:success)

          json_response = JSON.parse(response.body)
          expect(json_response.length).to eq(2)
          expect(json_response['included'].first['attributes']['details']).to eq('Sample event 2')
          expect(json_response['included'].second['attributes']['details']).to eq('Sample event 1')
        end
      end
    end

    context 'when there are no user actions' do
      it 'returns unauthorized' do
        get :index

        json_response = JSON.parse(response.body)
        expect(response).to have_http_status(:ok)
        expect(json_response['data'].length).to eq(0)
        expect(json_response['included'].length).to eq(0)
      end
    end
  end
end
