# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::UserActionEventsController, type: :controller do
  include RequestHelper

  describe 'GET #index' do
    subject { get(:index, params: index_params) }

    let(:index_params) { { start_date:, end_date:, page:, per_page: } }
    let(:start_date) { nil }
    let(:end_date) { nil }
    let(:page) { nil }
    let(:per_page) { nil }

    context 'when not logged in' do
      it 'returns unauthorized' do
        get :index
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when logged in' do
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
                               user_action_event: user_action_event_one, created_at: 1.year.ago)
        end
        let!(:user_action_two) do
          create(:user_action, subject_user_verification_id: user_verification.id,
                               user_action_event: user_action_event_two, created_at: 2.months.ago)
        end
        let!(:user_action_three) do
          create(:user_action, subject_user_verification_id: user_verification.id,
                               user_action_event: user_action_event_one, created_at: 3.weeks.ago)
        end
        let!(:user_action_four) do
          create(:user_action, subject_user_verification_id: user_verification.id,
                               user_action_event: user_action_event_two, created_at: 4.days.ago)
        end

        context 'when filtering by date range' do
          let(:start_date) { 3.months.ago.to_date }
          let(:end_date) { 2.weeks.ago.to_date }

          it 'returns the results in descending order by created_at' do
            json_response = JSON.parse(subject.body)['data']['data']
            expect(json_response.length).to eq(2)

            first_created_at = json_response.first['attributes']['created_at']
            second_created_at = json_response.second['attributes']['created_at']
            expect(first_created_at).to be > second_created_at
          end

          context 'when the start date and/or end dates are provided' do
            it 'returns user actions within the date range' do
              json_response = JSON.parse(subject.body)['data']['data']
              expect(json_response.length).to eq(2)
              expect(json_response.first['id']).to eq(user_action_three.id)
              expect(Time.zone.parse(json_response.first['attributes']['created_at'])).to be <= end_date
              expect(json_response.second['id']).to eq(user_action_two.id)
              expect(Time.zone.parse(json_response.second['attributes']['created_at'])).to be >= start_date
            end
          end

          context 'when the start date is not provided' do
            let(:start_date) { nil }
            let(:expected_start_date) { 1.month.ago.to_date }

            it 'returns user actions within the past month' do
              json_response = JSON.parse(subject.body)['data']['data']
              expect(json_response.length).to eq(1)
              expect(json_response.first['id']).to eq(user_action_three.id)
              expect(Time.zone.parse(json_response.first['attributes']['created_at'])).to be >= expected_start_date
            end
          end

          context 'when the end date is not provided' do
            let(:end_date) { nil }
            let(:expected_end_date) { Time.zone.now }

            it 'returns user actions up to the current date' do
              json_response = JSON.parse(subject.body)['data']['data']
              expect(json_response.length).to eq(3)
              expect(json_response.first['id']).to eq(user_action_four.id)
              expect(Time.zone.parse(json_response.first['attributes']['created_at'])).to be <= expected_end_date
              expect(json_response.second['id']).to eq(user_action_three.id)
              expect(json_response.third['id']).to eq(user_action_two.id)
            end
          end
        end

        context 'pagination' do
          let!(:user_action_event) { create(:user_action_event) }

          before do
            11.times do
              create(:user_action, user_action_event:, subject_user_verification_id: user_verification.id)
            end
          end

          context 'when the per_page parameter is not provided' do
            it 'paginates the user actions with a default of 10 per page' do
              json_response = JSON.parse(subject.body)

              json_response_data = json_response['data']['data']
              json_response_included = json_response['data']['included']

              expect(json_response_data.length).to eq(10)
              expect(json_response_included.length).to eq(1)
              expect(json_response_included.first['attributes']['identifier']).not_to be_nil
            end
          end

          context 'when the per_page parameter is provided' do
            let(:per_page) { 5 }

            it 'paginates the correct number of user actions per page' do
              json_response = JSON.parse(subject.body)

              json_response_per_page = json_response['meta']['per_page']
              json_response_current_page = json_response['meta']['current_page']
              json_response_included = json_response['data']['included']
              json_response_data = json_response['data']['data']

              expect(json_response_current_page).to eq(1)
              expect(json_response_per_page).to eq(per_page)
              expect(json_response_data.length).to eq(per_page)
              expect(json_response_included.length).to eq(1)
              expect(json_response_included.first['attributes']['event_type']).not_to be_nil
            end
          end

          context 'when the page parameter is not provided' do
            it 'returns the first page of user actions' do
              json_response_current_page = JSON.parse(subject.body)['meta']['current_page']

              expect(json_response_current_page).to eq(1)
            end
          end

          context 'when the page parameter is provided' do
            let(:page) { 2 }

            it 'returns the correct page of user actions' do
              json_response = JSON.parse(subject.body)

              json_response_current_page = json_response['meta']['current_page']
              json_response_data = json_response['data']['data']

              expect(json_response_data.length).to eq(3)
              expect(json_response_current_page).to eq(page)
            end
          end
        end

        it 'returns a successful response' do
          expect(subject).to have_http_status(:success)
        end

        it 'includes the user action event' do
          json_response = JSON.parse(subject.body)['data']

          expect(json_response['data'].length).to eq(2)
          expect(json_response['included'].first['attributes']['details']).to eq('Sample event 2')
          expect(json_response['included'].second['attributes']['details']).to eq('Sample event 1')
        end
      end

      context 'when there are no user actions' do
        it 'returns an empty array' do
          json_response = JSON.parse(subject.body)['data']
          expect(response).to have_http_status(:ok)
          expect(json_response['data'].length).to eq(0)
          expect(json_response['included'].length).to eq(0)
        end
      end
    end
  end
end
