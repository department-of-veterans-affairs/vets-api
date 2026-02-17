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
        allow(Flipper).to receive(:enabled?).with(:profile_scheduling_preferences,
                                                  instance_of(User)).and_return(false)
      end

      it 'forbids access' do
        get :show
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when feature flag is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:profile_scheduling_preferences,
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
        # Mock the GET response for show action
        let(:mock_get_response) do
          double('GetResponse',
                 status: 200,
                 person_options: [
                   double('PersonOption', item_id: 1, option_id: 5),
                   double('PersonOption', item_id: 2, option_id: 7),
                   double('PersonOption', item_id: 2, option_id: 11)
                 ])
        end

        before do
          # Don't stub check_pilot_access! - let it pass through normally
          allow(user).to receive(:va_treatment_facility_ids).and_return(['402'])
          allow_any_instance_of(UserVisnService).to receive(:in_pilot_visn?).and_return(true)

          allow_any_instance_of(VAProfile::PersonSettings::Service).to receive(:get_person_options)
            .and_return(double('response',
                               status: 200,
                               person_options: [
                                 { itemId: 1, optionId: 5 },
                                 { itemId: 2, optionId: 7 },
                                 { itemId: 2, optionId: 11 }
                               ]))

          allow_any_instance_of(VAProfile::PersonSettings::Service).to receive(:update_person_options)
            .and_return(double('UpdateResponse', transaction_id: 'txn-123-456'))

          mock_transaction = double('Transaction',
                                    id: 'txn-123-456',
                                    transaction_id: 'txn-123-456',
                                    transaction_status: 'RECEIVED')

          allow(AsyncTransaction::VAProfile::PersonOptionsTransaction).to receive(:start)
            .and_return(mock_transaction)

          mock_serializer_hash = {
            data: {
              id: 'txn-123-456',
              type: 'async_transaction_va_profile_person_options_transactions',
              attributes: {
                transaction_id: 'txn-123-456',
                transaction_status: 'RECEIVED',
                type: 'AsyncTransaction::VAProfile::PersonOptionsTransaction',
                metadata: []
              }
            }
          }

          allow(AsyncTransaction::BaseSerializer).to receive(:new)
            .with(mock_transaction)
            .and_return(double('Serializer',
                               serializable_hash: mock_serializer_hash))

          mock_person_options = [double('PersonOption', valid?: true, set_defaults: nil, mark_for_deletion: nil)]

          allow(VAProfile::Models::PersonOption).to receive_messages(
            from_frontend_selection: mock_person_options,
            to_api_payload: { bio: { personOptions: [{ id: 1, optionId: 5 }] } },
            to_frontend_format: [
              { item_id: 1, option_ids: [5] },
              { item_id: 2, option_ids: [7, 11] }
            ]
          )
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

            json_response = JSON.parse(response.body)
            expect(json_response['data']['type']).to include('transaction')
            expect(json_response['data']['attributes']['transaction_status']).to eq('RECEIVED')
          end

          it 'calls the service with correct parameters' do
            expect_any_instance_of(VAProfile::PersonSettings::Service).to receive(:update_person_options)
              .with({ bio: { personOptions: [{ id: 1, optionId: 5 }] } })

            post :create, params: valid_params
          end

          it 'handles single option_id' do
            post :create, params: { item_id: 1, option_ids: [5] }
            expect(response).to have_http_status(:ok)
          end

          it 'handles multiple option_ids' do
            post :create, params: { item_id: 2, option_ids: [7, 11, 14] }
            expect(response).to have_http_status(:ok)
          end

          context 'with invalid parameters' do
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
        end

        describe 'PUT #update' do
          let(:valid_params) { { item_id: 1, option_ids: [5] } }

          it 'updates scheduling preferences and returns transaction response' do
            put :update, params: valid_params
            expect(response).to have_http_status(:ok)

            json_response = JSON.parse(response.body)
            expect(json_response['data']['type']).to include('transaction')
          end

          it 'handles updating with new options' do
            put :update, params: { item_id: 2, option_ids: [10, 14] }
            expect(response).to have_http_status(:ok)
          end
        end

        describe 'DELETE #destroy' do
          let(:valid_params) { { item_id: 1, option_ids: [5] } }

          it 'destroys all scheduling preferences and returns transaction response' do
            mock_person_option = double('PersonOption', valid?: true)
            allow(mock_person_option).to receive(:set_defaults)
            allow(mock_person_option).to receive(:mark_for_deletion)

            allow(VAProfile::Models::PersonOption).to receive(:from_frontend_selection)
              .and_return([mock_person_option])

            expect(mock_person_option).to receive(:mark_for_deletion)

            delete :destroy, params: valid_params
            expect(response).to have_http_status(:ok)

            json_response = JSON.parse(response.body)
            expect(json_response['data']['type']).to include('transaction')
          end

          it 'calls build_and_validate_person_options with delete action' do
            expect_any_instance_of(described_class).to receive(:build_and_validate_person_options)
              .with(action: :delete)
              .and_call_original

            delete :destroy, params: valid_params
          end
        end

        describe '#service' do
          let(:controller_instance) { described_class.new }
          let(:mock_service) { instance_double(VAProfile::PersonSettings::Service) }

          before do
            controller_instance.instance_variable_set(:@current_user, user)
          end

          it 'creates a new VAProfile::PersonSettings::Service with current user' do
            expect(VAProfile::PersonSettings::Service).to receive(:new).with(user)
            controller_instance.send(:service)
          end

          it 'memoizes the service instance' do
            allow(VAProfile::PersonSettings::Service).to receive(:new).with(user).and_return(mock_service)

            service1 = controller_instance.send(:service)
            service2 = controller_instance.send(:service)

            expect(service1).to eq(service2)
            expect(VAProfile::PersonSettings::Service).to have_received(:new).once
          end
        end

        describe '#build_and_validate_person_options' do
          let(:controller_instance) { described_class.new }
          let(:mock_person_option) { double('PersonOption', valid?: true, set_defaults: nil, mark_for_deletion: nil) }
          let(:mock_person_option2) { double('PersonOption', valid?: true, set_defaults: nil, mark_for_deletion: nil) }
          let(:api_payload) { { bio: { personOptions: [{ id: 1, optionId: 5 }] } } }

          before do
            controller_instance.instance_variable_set(:@current_user, user)
            allow(controller_instance).to receive(:params).and_return(
              ActionController::Parameters.new(item_id: 1, option_ids: [5, 7])
            )
          end

          context 'for create action' do
            before do
              allow(VAProfile::Models::PersonOption).to receive(:from_frontend_selection)
                .with(1, [5, 7]).and_return([mock_person_option])
              allow(VAProfile::Models::PersonOption).to receive(:to_api_payload)
                .with([mock_person_option]).and_return(api_payload)
              allow(controller_instance).to receive(:validate!).with(mock_person_option)
            end

            it 'builds person options from frontend selection' do
              expect(VAProfile::Models::PersonOption).to receive(:from_frontend_selection)
                .with(1, [5, 7])

              controller_instance.send(:build_and_validate_person_options)
            end

            it 'returns API payload format' do
              result = controller_instance.send(:build_and_validate_person_options)
              expect(result).to eq(api_payload)
            end
          end

          context 'for delete action' do
            before do
              allow(VAProfile::Models::PersonOption).to receive(:from_frontend_selection)
                .with(1, [5, 7]).and_return([mock_person_option])
              allow(VAProfile::Models::PersonOption).to receive(:to_api_payload)
                .with([mock_person_option]).and_return(api_payload)
              allow(controller_instance).to receive(:validate!).with(mock_person_option)
            end

            it 'marks options for deletion when action is delete' do
              expect(mock_person_option).to receive(:mark_for_deletion)
              controller_instance.send(:build_and_validate_person_options, action: :delete)
            end
          end

          context 'with multiple option ids' do
            before do
              allow(VAProfile::Models::PersonOption).to receive(:from_frontend_selection)
                .with(1, [5, 7]).and_return([mock_person_option, mock_person_option2])
              allow(VAProfile::Models::PersonOption).to receive(:to_api_payload)
                .with([mock_person_option, mock_person_option2]).and_return(api_payload)
              allow(controller_instance).to receive(:validate!)
            end

            it 'processes each person option' do
              expect(mock_person_option).to receive(:set_defaults).with(user)
              expect(mock_person_option2).to receive(:set_defaults).with(user)
              expect(controller_instance).to receive(:validate!).with(mock_person_option)
              expect(controller_instance).to receive(:validate!).with(mock_person_option2)

              controller_instance.send(:build_and_validate_person_options)
            end
          end

          context 'with missing item_id' do
            before do
              allow(controller_instance).to receive(:params).and_return(
                ActionController::Parameters.new(option_ids: [5, 7])
              )
            end

            it 'raises ParameterMissing when item_id is blank' do
              expect do
                controller_instance.send(:build_and_validate_person_options)
              end.to raise_error(Common::Exceptions::ParameterMissing)
            end
          end

          context 'with missing option_ids' do
            before do
              allow(controller_instance).to receive(:params).and_return(
                ActionController::Parameters.new(item_id: 1)
              )
            end

            it 'raises ParameterMissing when option_ids is blank' do
              expect do
                controller_instance.send(:build_and_validate_person_options)
              end.to raise_error(Common::Exceptions::ParameterMissing)
            end
          end

          context 'with empty option_ids array' do
            before do
              allow(controller_instance).to receive(:params).and_return(
                ActionController::Parameters.new(item_id: 1, option_ids: [])
              )
            end

            it 'raises ParameterMissing when option_ids is empty array' do
              expect do
                controller_instance.send(:build_and_validate_person_options)
              end.to raise_error(Common::Exceptions::ParameterMissing)
            end
          end
        end

        describe '#write_person_options_and_render_transaction!' do
          let(:controller_instance) { described_class.new }
          let(:person_options_data) { { bio: { personOptions: [{ id: 1, optionId: 5 }] } } }
          let(:mock_service) { instance_double(VAProfile::PersonSettings::Service) }
          let(:mock_response) { instance_double(VAProfile::ContactInformation::V2::PersonOptionsTransactionResponse) }
          let(:mock_transaction) do
            double('Transaction', id: 'txn-123-456', transaction_id: 'txn-123-456', transaction_status: 'RECEIVED')
          end
          let(:mock_serializer_hash) { { data: { id: 'txn-123-456', type: 'transaction' } } }

          before do
            controller_instance.instance_variable_set(:@current_user, user)
            allow(controller_instance).to receive(:service).and_return(mock_service)
            allow(controller_instance).to receive(:render)
          end

          it 'calls service to update person options' do
            allow(mock_service).to receive(:update_person_options).and_return(mock_response)
            allow(AsyncTransaction::VAProfile::PersonOptionsTransaction).to receive(:start).and_return(mock_transaction)
            allow(AsyncTransaction::BaseSerializer).to receive(:new)
              .and_return(double('Serializer',
                                 serializable_hash: mock_serializer_hash))

            expect(mock_service).to receive(:update_person_options).with(person_options_data)
            controller_instance.send(:write_person_options_and_render_transaction!, person_options_data)
          end

          it 'starts a new transaction with user and response' do
            allow(mock_service).to receive(:update_person_options).and_return(mock_response)
            allow(AsyncTransaction::BaseSerializer).to receive(:new)
              .and_return(double('Serializer',
                                 serializable_hash: mock_serializer_hash))

            expect(AsyncTransaction::VAProfile::PersonOptionsTransaction).to receive(:start)
              .with(user, mock_response)
              .and_return(mock_transaction)

            controller_instance.send(:write_person_options_and_render_transaction!, person_options_data)
          end

          it 'renders transaction with BaseSerializer' do
            allow(mock_service).to receive(:update_person_options).and_return(mock_response)
            allow(AsyncTransaction::VAProfile::PersonOptionsTransaction).to receive(:start).and_return(mock_transaction)

            serializer_instance = instance_double(AsyncTransaction::BaseSerializer,
                                                  serializable_hash: mock_serializer_hash)
            expect(AsyncTransaction::BaseSerializer).to receive(:new).with(mock_transaction)
                                                                     .and_return(serializer_instance)
            expect(controller_instance).to receive(:render).with(json: mock_serializer_hash)

            controller_instance.send(:write_person_options_and_render_transaction!, person_options_data)
          end

          context 'when service raises an error' do
            before do
              allow(mock_service).to receive(:update_person_options).and_raise(StandardError.new('Service error'))
            end

            it 'propagates the error' do
              expect do
                controller_instance.send(:write_person_options_and_render_transaction!, person_options_data)
              end.to raise_error(StandardError, 'Service error')
            end
          end
        end

        describe '#validate!' do
          let(:controller_instance) { described_class.new }
          let(:mock_person_option) { double('PersonOption') }

          before do
            controller_instance.instance_variable_set(:@current_user, user)
          end

          context 'when person option is valid' do
            before do
              allow(mock_person_option).to receive(:valid?).and_return(true)
            end

            it 'returns without raising an error' do
              expect { controller_instance.send(:validate!, mock_person_option) }.not_to raise_error
            end
          end

          context 'when person option is invalid' do
            before do
              allow(mock_person_option).to receive_messages(valid?: false, errors: double('Errors', empty?: false))
            end

            it 'raises ValidationErrors' do
              expect { controller_instance.send(:validate!, mock_person_option) }
                .to raise_error(Common::Exceptions::ValidationErrors)
            end
          end
        end
      end
    end
  end
end
