# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::AccountControlsController, type: :controller do
  let(:service_account_access_token) { build(:service_account_access_token) }
  let(:user_account) { create(:user_account) }
  let!(:logingov_user_verification) { create(:logingov_user_verification, user_account:, locked:) }
  let(:logingov_uuid) { logingov_user_verification.logingov_uuid }
  let!(:idme_user_verification) { create(:idme_user_verification, user_account:, locked:) }
  let(:idme_uuid) { idme_user_verification.idme_uuid }
  let(:type) { 'logingov' }
  let(:csp_uuid) { type == 'logingov' ? logingov_uuid : idme_uuid }
  let(:icn) { user_account.icn }
  let(:type_param) { type }
  let(:csp_uuid_param) { csp_uuid }
  let(:icn_param) { icn }
  let(:account_controls_params) { { type: type_param, csp_uuid: csp_uuid_param, icn: icn_param } }
  let(:expected_response_data) do
    { 'csp_uuid' => csp_uuid,
      'type' => type,
      'icn' => icn,
      'locked' => expected_lock_status,
      'updated_by' => service_account_access_token.user_identifier }
  end

  before do
    allow_any_instance_of(V0::AccountControlsController).to receive(:authenticate_service_account).and_return(true)
    controller.instance_variable_set(:@service_account_access_token, service_account_access_token)
  end

  shared_context 'when validating params and querying a UserVerification' do
    shared_context 'when a record is not found' do
      let(:expected_error_message) { "User record not found. ICN:#{icn_param} #{type_param}_uuid:#{csp_uuid_param}" }

      it 'returns a not found error' do
        expect { post lock_action, params: account_controls_params }
          .to raise_error(StandardError, expected_error_message)
      end
    end

    shared_examples 'when a record is found' do
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

    context 'when a request is made with a type that is not logingov or idme' do
      let(:type_param) { 'some-csp-type' }
      let(:expected_error_message) { "\"#{type_param}\" is not a valid value for \"type\"" }

      it 'returns a type parameter missing error' do
        post lock_action, params: account_controls_params

        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)['errors'].first['detail']).to eq(expected_error_message)
      end
    end

    context 'when a request is made with an ICN' do
      context 'when a UserAccount matches the requested ICN' do
        it_behaves_like 'when a record is found'
      end

      context 'when a UserAccount does not match the requested ICN' do
        let(:icn_param) { 'some-icn' }

        it_behaves_like 'when a record is not found'
      end
    end

    context 'when a request is made without an ICN' do
      let(:icn_param) { nil }

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
  end

  shared_context 'when a requested idme uuid is connected to multiple idme-backed UserVerifications' do
    let!(:dslogon_user_verification) { create(:dslogon_user_verification, backing_idme_uuid: idme_uuid, user_account:) }
    let!(:mhv_user_verification) { create(:mhv_user_verification, backing_idme_uuid: idme_uuid, user_account:) }

    it 'updates all UserVerifications with a matching UserAccount id that are not logingov' do
      post lock_action, params: account_controls_params

      expect(dslogon_user_verification.reload.locked).to eq(expected_lock_status)
      expect(mhv_user_verification.reload.locked).to eq(expected_lock_status)
    end
  end

  describe 'POST csp_lock' do
    let(:locked) { false }
    let(:lock_action) { :csp_lock }
    let(:expected_lock_status) { true }

    context 'when a logingov uuid is requested' do
      it_behaves_like 'when validating params and querying a UserVerification'
    end

    context 'when an idme uuid is requested' do
      let(:type) { 'idme' }

      it_behaves_like 'when validating params and querying a UserVerification'
      it_behaves_like 'when a requested idme uuid is connected to multiple idme-backed UserVerifications'
    end
  end

  describe 'POST csp_unlock' do
    let(:locked) { true }
    let(:lock_action) { :csp_unlock }
    let(:expected_lock_status) { false }

    context 'when a logingov uuid is requested' do
      it_behaves_like 'when validating params and querying a UserVerification'
    end

    context 'when an idme uuid is requested' do
      let(:type) { 'idme' }

      it_behaves_like 'when validating params and querying a UserVerification'
      it_behaves_like 'when a requested idme uuid is connected to multiple idme-backed UserVerifications'
    end
  end
end
