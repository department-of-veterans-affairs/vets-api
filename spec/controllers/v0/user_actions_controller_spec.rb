# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::UserActionsController, type: :controller do
  describe 'GET #index' do
    subject(:index_request) { get :index, params: request_params }

    let(:idme_uuid) { 'some-idme-uuid' }
    let(:user) { create(:user, idme_uuid:) }
    let!(:subject_user_verification) { create(:idme_user_verification, idme_uuid:) }

    let(:page) { nil }
    let(:per_page) { nil }
    let(:query_params) { {} }
    let(:request_params) do
      {
        page:,
        per_page:,
        q: query_params
      }.compact_blank
    end

    context 'when not authenticated' do
      it 'returns unauthorized' do
        get :index
        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when authenticated' do
      before do
        sign_in(user)
      end

      context 'with no user user_actions' do
        it 'returns empty data and included arrays' do
          index_request
          response_body = JSON.parse(response.body)

          expect(response_body['data']).to be_empty
          expect(response_body['included']).to be_empty
        end
      end

      context 'with existing user user_actions' do
        let(:user_action_events) { create_list(:user_action_event, 2) }
        let!(:user_actions) do
          [1.year.ago, 2.months.ago, 3.weeks.ago, 4.days.ago]
            .map.with_index do |created_at, index|
              create(:user_action, subject_user_verification:, user_action_event: user_action_events[index % 2],
                                   created_at:)
            end
        end

        it 'returns success and includes user_action_events' do
          index_request
          body = JSON.parse(response.body)
          included = body['included']

          expect(response).to have_http_status(:success)
          expect(included).to all(include('type' => 'user_action_event'))
        end

        context 'with pagination' do
          let!(:user_actions) do
            create_list(:user_action, 13, subject_user_verification:, user_action_event: user_action_events.first)
          end

          context 'default page and per_page' do
            it 'returns 10 items and correct meta' do
              index_request
              body = JSON.parse(response.body)

              expect(body['data'].size).to eq(10)
              expect(body['meta']).to include(
                'per_page' => 10,
                'current_page' => 1,
                'total_pages' => 2,
                'total_count' => 13
              )
            end
          end

          context 'with page param' do
            let(:page) { 2 }

            it 'returns remaining items' do
              index_request

              expect(JSON.parse(response.body)['data'].size).to eq(3)
            end
          end

          context 'with per_page param' do
            let(:per_page) { 5 }

            it 'uses custom per_page and calculates meta' do
              index_request
              body = JSON.parse(response.body)

              expect(body['data'].size).to eq(5)
              expect(body['meta']).to include(
                'per_page' => 5,
                'total_pages' => 3,
                'total_count' => 13
              )
            end
          end
        end

        context 'with date filtering' do
          let(:query_params) do
            {
              created_at_gteq: 3.months.ago.to_date,
              created_at_lteq: 2.weeks.ago.to_date
            }
          end

          it 'filters by date range and sorts descending' do
            index_request
            data = JSON.parse(response.body)['data']
            dates = data.map { |d| Time.zone.parse(d['attributes']['created_at']) }

            expect(data.map { |d| d['id'] }).to contain_exactly(user_actions[2].id, user_actions[1].id)
            expect(dates).to eq(dates.sort.reverse)
          end
        end

        context 'with sorting filters' do
          %w[asc desc].each do |direction|
            context "sorted by created_at #{direction}" do
              let(:query_params) { { s: "created_at #{direction}" } }

              it 'sorts correctly' do
                index_request
                dates = JSON.parse(response.body)['data'].map { |d| Time.zone.parse(d['attributes']['created_at']) }
                expected = direction == 'asc' ? dates.sort : dates.sort.reverse

                expect(dates).to eq(expected)
              end
            end
          end
        end

        context 'with user_action status filter' do
          %w[success error initial].each do |status|
            context "status_eq #{status}" do
              let(:query_params) { { status_eq: status } }

              before do
                create_list(:user_action, 5,
                            subject_user_verification:,
                            status:,
                            user_action_event: user_action_events.first)
              end

              it 'returns only matching statuses' do
                index_request
                statuses = JSON.parse(response.body)['data'].map { |d| d['attributes']['status'] }

                expect(statuses).to all(eq(status))
              end
            end
          end
        end

        context 'with user_action_event event_type filter' do
          let(:event) { create(:user_action_event, event_type: 'custom-type') }
          let(:query_params) { { user_action_event_event_type_eq: event.event_type } }

          before do
            create_list(:user_action, 5, subject_user_verification:, user_action_event: event)
          end

          it 'filters by event_type' do
            index_request
            ids = JSON.parse(response.body)['data'].map { |d| d['attributes']['user_action_event_id'] }

            expect(ids).to all(eq(event.id))
          end
        end
      end
    end
  end
end
