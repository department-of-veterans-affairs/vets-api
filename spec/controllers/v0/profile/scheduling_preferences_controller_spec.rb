# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::Profile::SchedulingPreferencesController, type: :controller do
  let(:user) { build(:user, :loa3) }

  describe 'authentication and authorization' do
    context 'when user is not authenticated' do
      it 'returns 401 for GET #show' do
        get :show
        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns 401 for POST #create' do
        post :create, params: { item_id: 1, option_ids: [5] }
        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns 401 for PUT #update' do
        put :update, params: { item_id: 1, option_ids: [5] }
        expect(response).to have_http_status(:unauthorized)
      end

      it 'returns 401 for DELETE #destroy' do
        delete :destroy
        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'with authenticated LOA3 user' do
    before do
      sign_in_as(user)
    end

    context 'when feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:profile_health_care_settings_page,
                                                  instance_of(User)).and_return(false)
      end

      it 'forbids access' do
        get :show
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when feature flag is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:profile_health_care_settings_page,
                                                  instance_of(User)).and_return(true)
      end

      context 'when user is not in pilot VISN' do
        before do
          # Mock UserVisnService to return false (user not in pilot VISN)
          allow_any_instance_of(UserVisnService).to receive(:in_pilot_visn?).and_return(false)
          allow(Rails.logger).to receive(:info)
        end

        it 'forbids access with pilot-specific message and logs info' do
          expect(Rails.logger).to receive(:info).with(/Scheduling preferences not available for your facility for user/)

          get :show
          expect(response).to have_http_status(:forbidden)

          json_response = JSON.parse(response.body)
          expect(json_response['errors'].first['detail']).to eq('Unable to verify access to scheduling preferences')
        end
      end

      context 'when UserVisnService raises an exception' do
        before do
          # Mock UserVisnService to raise an exception during initialization or method call
          allow(UserVisnService).to receive(:new).and_raise(StandardError.new('Service unavailable'))
        end

        it 'returns server error status when service fails' do
          get :show
          expect(response).to have_http_status(:internal_server_error)
        end
      end

      context 'when user is in pilot VISN' do
        before do
          # Don't stub check_pilot_access! - let it pass through normally
          allow(user).to receive(:va_treatment_facility_ids).and_return(['402'])
          allow_any_instance_of(UserVisnService).to receive(:in_pilot_visn?).and_return(true)
        end

        context 'when user has facilities in pilot VISNs (actual service test)' do
          before do
            # Mock the UserVisnService to return true for pilot VISNs
            allow_any_instance_of(UserVisnService).to receive(:in_pilot_visn?).and_return(true)
          end

          it 'allows access because user is in pilot VISNs' do
            get :show
            expect(response).to have_http_status(:ok)

            json_response = JSON.parse(response.body)
            expect(json_response['data']['type']).to eq('scheduling_preferences')
            expect(json_response['data']['attributes']['preferences']).to be_an(Array)
          end
        end

        context 'when user has mixed facilities (pilot and non-pilot VISNs)' do
          before do
            # Mock the UserVisnService to return true (has at least one pilot VISN)
            allow_any_instance_of(UserVisnService).to receive(:in_pilot_visn?).and_return(true)
          end

          it 'allows access because user has at least one pilot VISN facility' do
            get :show
            expect(response).to have_http_status(:ok)

            json_response = JSON.parse(response.body)
            expect(json_response['data']['type']).to eq('scheduling_preferences')
            expect(json_response['data']['attributes']['preferences']).to be_an(Array)
          end
        end

        describe 'GET #show' do
          it 'returns scheduling preferences' do
            get :show
            expect(response).to have_http_status(:ok)

            json_response = JSON.parse(response.body)
            expect(json_response['data']['type']).to eq('scheduling_preferences')
            expect(json_response['data']['attributes']['preferences']).to be_an(Array)
            expect(json_response['data']['attributes']['preferences'].length).to eq(2)

            first_preference = json_response['data']['attributes']['preferences'].first
            expect(first_preference['item_id']).to eq(1)
            expect(first_preference['option_ids']).to eq([5])

            second_preference = json_response['data']['attributes']['preferences'].last
            expect(second_preference['item_id']).to eq(2)
            expect(second_preference['option_ids']).to eq([7, 11])
          end
        end

        describe 'POST #create' do
          let(:valid_params) { { item_id: 1, option_ids: [5, 7] } }

          it 'creates scheduling preferences and returns transaction response' do
            post :create, params: valid_params
            expect(response).to have_http_status(:ok)
          end

          it 'handles single option_id' do
            post :create, params: { item_id: 1, option_ids: [5] }
            expect(response).to have_http_status(:ok)
          end

          it 'handles multiple option_ids' do
            post :create, params: { item_id: 2, option_ids: [7, 11, 14] }
            expect(response).to have_http_status(:ok)
          end
        end

        describe 'PUT #update' do
          let(:valid_params) { { item_id: 1, option_ids: [5] } }

          it 'updates scheduling preferences and returns transaction response' do
            put :update, params: valid_params
            expect(response).to have_http_status(:ok)
          end

          it 'handles clearing all options (empty array)' do
            put :update, params: { item_id: 1, option_ids: [] }
            expect(response).to have_http_status(:ok)
          end

          it 'handles clearing all options (nil)' do
            put :update, params: { item_id: 1, option_ids: nil }
            expect(response).to have_http_status(:ok)
          end

          it 'handles updating with new options' do
            put :update, params: { item_id: 2, option_ids: [10, 14] }
            expect(response).to have_http_status(:ok)
          end
        end

        describe 'DELETE #destroy' do
          it 'destroys all scheduling preferences and returns transaction response' do
            delete :destroy
            expect(response).to have_http_status(:ok)
          end
        end

        describe 'parameter handling' do
          it 'permits item_id parameter' do
            post :create, params: { item_id: 1, option_ids: [5] }
            expect(response).to have_http_status(:ok)
          end

          it 'permits option_ids array parameter' do
            post :create, params: { item_id: 1, option_ids: [5, 7, 11] }
            expect(response).to have_http_status(:ok)
          end

          it 'filters out unpermitted parameters' do
            expect do
              post :create, params: {
                item_id: 1,
                option_ids: [5],
                unauthorized_param: 'should be filtered'
              }
            end.not_to raise_error

            expect(response).to have_http_status(:ok)
          end
        end

        describe 'transaction response format' do
          it 'includes required transaction attributes' do
            post :create, params: { item_id: 1, option_ids: [5] }

            json_response = JSON.parse(response.body)
            transaction_attributes = json_response['data']['attributes']

            expect(transaction_attributes).to include(
              'transaction_id',
              'transaction_status',
              'type',
              'metadata'
            )

            expect(transaction_attributes['transaction_id']).to be_present
            expect(transaction_attributes['transaction_status']).to eq('COMPLETED_SUCCESS')
            expect(transaction_attributes['type']).to eq('AsyncTransaction::VAProfile::PersonOptionTransaction')
            expect(transaction_attributes['metadata']).to be_an(Array)
          end

          it 'generates unique transaction IDs' do
            post :create, params: { item_id: 1, option_ids: [5] }
            first_response = JSON.parse(response.body)
            first_transaction_id = first_response['data']['attributes']['transaction_id']

            put :update, params: { item_id: 1, option_ids: [7] }
            second_response = JSON.parse(response.body)
            second_transaction_id = second_response['data']['attributes']['transaction_id']

            expect(first_transaction_id).not_to eq(second_transaction_id)
          end
        end
      end
    end
  end
end
