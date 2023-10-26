# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::AccountControlsController, type: :controller do
  let(:service_account_access_token) { build(:service_account_access_token) }
  let(:user_account) { create(:user_account) }
  let(:locked) { false }
  let(:logingov_user_verification) { create(:logingov_user_verification, user_account:, locked:) }
  let(:idme_user_verification) { create(:idme_user_verification, user_account:, locked:) }
  let(:dslogon_user_verification) { create(:dslogon_user_verification, user_account:, locked:) }
  let(:mhv_user_verification) { create(:mhv_user_verification, user_account:, locked:) }

  before do
    allow_any_instance_of(V0::AccountControlsController).to receive(:authenticate_service_account).and_return(true)
    controller.instance_variable_set(:@service_account_access_token, service_account_access_token)
  end

  describe 'GET csp_index' do
    let(:icn) { user_account.icn }
    let(:icn_param) { icn }

    context 'without an ICN param' do
      let(:icn_param) { nil }
      let(:expected_error) { 'The required parameter "icn", is missing' }

      it 'returns a bad request error' do
        get :csp_index, params: { icn: icn_param }

        expect(response).to have_http_status(:bad_request)
        error = JSON.parse(response.body)['errors'].first
        expect(error['detail']).to eq(expected_error)
      end
    end

    context 'with an ICN param' do
      context 'when a record is not found' do
        let(:icn_param) { 'some-bad-icn' }
        let(:expected_error) { "User CSP Index not found. ICN:#{icn_param}" }

        it 'returns a not found error' do
          get :csp_index, params: { icn: icn_param }

          expect(response).to have_http_status(:not_found)
          error = JSON.parse(response.body)['error']
          expect(error).to eq(expected_error)
        end
      end

      context 'when one or more User Verifications are found' do
        let(:expected_csp_uuids) do
          [logingov_user_verification.logingov_uuid,
           idme_user_verification.idme_uuid,
           dslogon_user_verification.dslogon_uuid,
           mhv_user_verification.mhv_uuid]
        end

        before do
          logingov_user_verification
          idme_user_verification
          dslogon_user_verification
          mhv_user_verification
        end

        it 'returns serialized user account data' do
          get :csp_index, params: { icn: icn_param }

          expect(response).to have_http_status(:ok)
          serialized_data = JSON.parse(response.body)['data']
          expect(serialized_data['icn']).to eq(icn)
          expect(serialized_data['csp_verifications'].count).to eq(4)
          serialized_data['csp_verifications'].each do |csp_verification|
            expect(csp_verification['type']).to be_in(%w[logingov idme dslogon mhv])
            expect(csp_verification['csp_uuid']).to be_in(expected_csp_uuids)
          end
        end
      end
    end
  end

  shared_context 'when validating params and querying a UserVerification' do
    shared_examples 'when a record is not found' do
      let(:expected_error_message) { "User CSP record not found. #{type_param}_uuid:#{csp_uuid_param}" }

      it 'returns a not found error' do
        post lock_action, params: account_controls_params
        expect(JSON.parse(response.body)['error']).to eq(expected_error_message)
      end
    end

    shared_examples 'when a record is found' do
      context 'when the record is successfully updated' do
        it 'performs the requested lock action' do
          post lock_action, params: account_controls_params

          user_verification = UserVerification.find_by("#{type}_uuid": csp_uuid)
          expect(user_verification.locked).to eq(expected_lock_status)
        end

        it 'returns serialized user account data' do
          post lock_action, params: account_controls_params

          expect(response).to have_http_status(:ok)
          expect(JSON.parse(response.body)['data']).to eq(expected_response_data)
        end

        it 'logs the lock action' do
          allow(Rails.logger).to receive(:info)
          expect(Rails.logger).to receive(:info).with("UserAccount CSP #{expected_lock_action}", expected_response_log)
          post lock_action, params: account_controls_params
        end
      end

      context 'when the record is not successfully updated' do
        let(:expected_lock_status) { locked }
        let(:expected_error_message) do
          "User CSP record #{expected_lock_action} failed. #{type_param}_uuid:#{csp_uuid_param}"
        end

        before { allow_any_instance_of(UserVerification).to receive(:update).and_return(false) }

        it 'returns an internal server error' do
          post lock_action, params: account_controls_params

          expect(response).to have_http_status(:internal_server_error)
          expect(JSON.parse(response.body)['error']).to eq(expected_error_message)
        end

        it 'logs the lock attempt' do
          allow(Rails.logger).to receive(:info)
          expect(Rails.logger).to receive(:info).with("UserAccount CSP #{expected_lock_action} failed",
                                                      expected_response_log)

          post lock_action, params: account_controls_params
        end
      end
    end

    context 'when a request is made without a type' do
      let(:type_param) { nil }
      let(:expected_error_message) { 'The required parameter "type", is missing' }

      it 'returns a type parameter missing error' do
        post lock_action, params: account_controls_params

        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)['errors'].first['detail']).to eq(expected_error_message)
      end
    end

    context 'when a request is made with a type that is not found in VALID_CSP_TYPES' do
      let(:type_param) { 'some-csp-type' }
      let(:expected_error_message) { "\"#{type_param}\" is not a valid value for \"type\"" }

      it 'returns a type parameter missing error' do
        post lock_action, params: account_controls_params

        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)['errors'].first['detail']).to eq(expected_error_message)
      end
    end

    context 'when a request is made without a CSP uuid' do
      let(:csp_uuid_param) { nil }
      let(:expected_error_message) { 'The required parameter "csp_uuid", is missing' }

      it 'returns a CSP uuid parameter missing error' do
        post lock_action, params: account_controls_params

        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)['errors'].first['detail']).to eq(expected_error_message)
      end
    end

    context 'when a request is made with a CSP uuid' do
      context 'when a UserVerification matches the requested CSP uuid' do
        it_behaves_like 'when a record is found'
      end

      context 'when a UserVerification does not match the requested CSP uuid' do
        let(:csp_uuid_param) { 'some-csp-uuid' }

        it_behaves_like 'when a record is not found'
      end
    end
  end

  describe 'POST csp_lock' do
    let(:lock_action) { :csp_lock }
    let(:locked) { false }
    let(:type_param) { type }
    let(:csp_uuid_param) { csp_uuid }
    let(:account_controls_params) { { type: type_param, csp_uuid: csp_uuid_param } }
    let(:expected_lock_status) { true }
    let(:expected_lock_action) { lock_action == :csp_lock ? 'lock' : 'unlock' }
    let(:expected_response_data) do
      { 'csp_uuid' => csp_uuid,
        'type' => type,
        'locked' => expected_lock_status,
        'requested_by' => service_account_access_token.user_identifier }
    end
    let(:expected_response_log) do
      { csp_uuid:,
        type:,
        locked: expected_lock_status,
        requested_by: service_account_access_token.user_identifier }
    end

    context 'when a logingov uuid is requested' do
      let(:type) { 'logingov' }
      let(:csp_uuid) { logingov_user_verification.logingov_uuid }

      it_behaves_like 'when validating params and querying a UserVerification'
    end

    context 'when an idme uuid is requested' do
      let(:type) { 'idme' }
      let(:csp_uuid) { idme_user_verification.idme_uuid }

      it_behaves_like 'when validating params and querying a UserVerification'
    end

    context 'when a dslogon uuid is requested' do
      let(:type) { 'dslogon' }
      let(:csp_uuid) { dslogon_user_verification.dslogon_uuid }

      it_behaves_like 'when validating params and querying a UserVerification'
    end

    context 'when an mhv uuid is requested' do
      let(:type) { 'mhv' }
      let(:csp_uuid) { mhv_user_verification.mhv_uuid }

      it_behaves_like 'when validating params and querying a UserVerification'
    end
  end

  describe 'POST csp_unlock' do
    let(:lock_action) { :csp_unlock }
    let(:locked) { true }
    let(:user_account) { create(:user_account) }
    let(:type_param) { type }
    let(:csp_uuid_param) { csp_uuid }
    let(:account_controls_params) { { type: type_param, csp_uuid: csp_uuid_param } }
    let(:expected_lock_status) { false }
    let(:expected_lock_action) { lock_action == :csp_lock ? 'lock' : 'unlock' }
    let(:expected_response_data) do
      { 'csp_uuid' => csp_uuid,
        'type' => type,
        'locked' => expected_lock_status,
        'requested_by' => service_account_access_token.user_identifier }
    end
    let(:expected_response_log) do
      { csp_uuid:,
        type:,
        locked: expected_lock_status,
        requested_by: service_account_access_token.user_identifier }
    end

    context 'when a logingov uuid is requested' do
      let(:type) { 'logingov' }
      let(:csp_uuid) { logingov_user_verification.logingov_uuid }

      it_behaves_like 'when validating params and querying a UserVerification'
    end

    context 'when an idme uuid is requested' do
      let(:type) { 'idme' }
      let(:csp_uuid) { idme_user_verification.idme_uuid }

      it_behaves_like 'when validating params and querying a UserVerification'
    end

    context 'when a dslogon uuid is requested' do
      let(:type) { 'dslogon' }
      let(:csp_uuid) { dslogon_user_verification.dslogon_uuid }

      it_behaves_like 'when validating params and querying a UserVerification'
    end

    context 'when an mhv uuid is requested' do
      let(:type) { 'mhv' }
      let(:csp_uuid) { mhv_user_verification.mhv_uuid }

      it_behaves_like 'when validating params and querying a UserVerification'
    end
  end
end
