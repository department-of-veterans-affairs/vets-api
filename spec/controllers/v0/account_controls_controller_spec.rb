# frozen_string_literal: true

require 'rails_helper'

RSpec.describe V0::AccountControlsController, type: :controller do
  let(:service_account_access_token) { build(:service_account_access_token, user_attributes:) }
  let(:user_account) { create(:user_account) }
  let(:user_attributes) { {} }
  let(:locked) { false }
  let!(:logingov_user_verification) { create(:logingov_user_verification, user_account:, locked:) }
  let!(:idme_user_verification) { create(:idme_user_verification, user_account:, locked:) }
  let!(:dslogon_user_verification) { create(:dslogon_user_verification, user_account:, locked:) }
  let!(:mhv_user_verification) { create(:mhv_user_verification, user_account:, locked:) }

  before do
    allow_any_instance_of(SignIn::ServiceAccountAuthentication).to receive(:authenticate_service_account)
      .and_return(true)
    controller.instance_variable_set(:@service_account_access_token, service_account_access_token)
  end

  describe 'GET credential_index' do
    subject { get :credential_index }

    let(:user_attributes) { { 'icn' => requested_icn } }

    context 'without an ICN param' do
      let(:requested_icn) { nil }
      let(:expected_error) { 'icn is not defined' }

      it 'returns a bad request error' do
        expect(subject).to have_http_status(:bad_request)
        expect(JSON.parse(subject.body)['error']).to eq(expected_error)
      end
    end

    context 'with an ICN param' do
      context 'when a record is not found' do
        let(:requested_icn) { 'some-bad-icn' }
        let(:expected_error) { 'UserAccount not found.' }

        it 'returns a not found error' do
          expect(subject).to have_http_status(:not_found)
          expect(JSON.parse(subject.body)['error']).to eq(expected_error)
        end
      end

      context 'when one or more User Verifications are found' do
        let(:requested_icn) { user_account.icn }
        let(:expected_response_data) do
          [{ 'type' => 'logingov', 'credential_id' => logingov_user_verification.logingov_uuid, 'locked' => false },
           { 'type' => 'idme', 'credential_id' => idme_user_verification.idme_uuid, 'locked' => false },
           { 'type' => 'dslogon', 'credential_id' => dslogon_user_verification.dslogon_uuid, 'locked' => false },
           { 'type' => 'mhv', 'credential_id' => mhv_user_verification.mhv_uuid, 'locked' => false }]
        end

        it 'returns serialized user account data' do
          expect(subject).to have_http_status(:ok)
          expect(JSON.parse(response.body)['data']).to eq(expected_response_data)
        end
      end
    end
  end

  shared_context 'when validating params and querying a UserVerification' do
    subject { post lock_action }

    let(:user_attributes) { { 'type' => requested_type, 'credential_id' => requested_credential_id } }

    shared_examples 'when a record is not found' do
      let(:expected_error_message) { 'UserAccount credential record not found.' }

      it 'returns a not found error' do
        expect(JSON.parse(subject.body)['error']).to eq(expected_error_message)
      end
    end

    shared_examples 'when a record is found' do
      let(:user_verification) { UserVerification.find_by_type!(type, credential_id) }

      context 'when the record is successfully updated' do
        let(:expected_log_message) do
          "[V0::AccountControlsController] credential_#{expected_lock_action}"
        end

        before { allow(Rails.logger).to receive(:info) }

        it 'performs the requested lock action' do
          expect do
            subject
            user_verification.reload
          end.to change(user_verification, :locked).from(locked).to(expected_lock_status)
        end

        it 'returns serialized user account data' do
          expect(subject).to have_http_status(:ok)
          expect(JSON.parse(subject.body)['data']).to eq(expected_response_data)
        end

        it 'logs the lock action' do
          expect(Rails.logger).to receive(:info).with(expected_log_message, expected_response_log)
          subject
        end
      end

      context 'when the record is not successfully updated' do
        let(:expected_lock_status) { locked }
        let(:expected_error_message) do
          "UserAccount credential #{expected_lock_action} failed."
        end
        let(:expected_log_message) do
          "[V0::AccountControlsController] credential_#{expected_lock_action} failed"
        end

        before do
          allow_any_instance_of(UserVerification).to receive(expected_lock_method)
            .and_raise(ActiveRecord::RecordInvalid)
          allow(Rails.logger).to receive(:info)
        end

        it 'returns an internal server error' do
          expect(subject).to have_http_status(:internal_server_error)
          expect(JSON.parse(subject.body)['error']).to eq(expected_error_message)
        end

        it 'logs the lock attempt' do
          expect(Rails.logger).to receive(:info).with(expected_log_message, expected_response_log)
          subject
        end
      end
    end

    context 'when a request is made without a type' do
      let(:requested_type) { nil }
      let(:expected_error_message) { 'type is not defined' }

      it 'returns a type parameter missing error' do
        expect(subject).to have_http_status(:bad_request)
        expect(JSON.parse(subject.body)['error']).to eq(expected_error_message)
      end
    end

    context 'when a request is made with a type that is not found in VALID_CSP_TYPES' do
      let(:requested_type) { 'some-csp-type' }
      let(:expected_error_message) { 'type is malformed' }

      it 'returns a type parameter missing error' do
        expect(subject).to have_http_status(:bad_request)
        expect(JSON.parse(subject.body)['error']).to eq(expected_error_message)
      end
    end

    context 'when a request is made without a CSP uuid' do
      let(:requested_credential_id) { nil }
      let(:expected_error_message) { 'credential_id is not defined' }

      it 'returns a CSP uuid parameter missing error' do
        expect(subject).to have_http_status(:bad_request)
        expect(JSON.parse(subject.body)['error']).to eq(expected_error_message)
      end
    end

    context 'when a request is made with a CSP uuid' do
      context 'when a UserVerification matches the requested CSP uuid' do
        it_behaves_like 'when a record is found'
      end

      context 'when a UserVerification does not match the requested CSP uuid' do
        let(:requested_credential_id) { 'some-csp-uuid' }

        it_behaves_like 'when a record is not found'
      end
    end
  end

  describe 'POST credential_lock' do
    let(:lock_action) { :credential_lock }
    let(:locked) { false }
    let(:requested_type) { type }
    let(:requested_credential_id) { credential_id }
    let(:expected_lock_status) { true }
    let(:expected_lock_action) { 'lock' }
    let(:expected_lock_method) { :lock! }
    let(:expected_response_data) do
      { 'credential_id' => credential_id,
        'type' => type,
        'locked' => expected_lock_status }
    end
    let(:expected_response_log) do
      { credential_id:,
        type:,
        locked: expected_lock_status,
        requested_by: service_account_access_token.user_identifier }
    end

    context 'when a logingov uuid is requested' do
      let(:type) { 'logingov' }
      let(:credential_id) { logingov_user_verification.logingov_uuid }

      it_behaves_like 'when validating params and querying a UserVerification'
    end

    context 'when an idme uuid is requested' do
      let(:type) { 'idme' }
      let(:credential_id) { idme_user_verification.idme_uuid }

      it_behaves_like 'when validating params and querying a UserVerification'
    end

    context 'when a dslogon uuid is requested' do
      let(:type) { 'dslogon' }
      let(:credential_id) { dslogon_user_verification.dslogon_uuid }

      it_behaves_like 'when validating params and querying a UserVerification'
    end

    context 'when an mhv uuid is requested' do
      let(:type) { 'mhv' }
      let(:credential_id) { mhv_user_verification.mhv_uuid }

      it_behaves_like 'when validating params and querying a UserVerification'
    end
  end

  describe 'POST credential_unlock' do
    let(:lock_action) { :credential_unlock }
    let(:locked) { true }
    let(:requested_type) { type }
    let(:requested_credential_id) { credential_id }
    let(:expected_lock_status) { false }
    let(:expected_lock_action) { 'unlock' }
    let(:expected_lock_method) { :unlock! }
    let(:expected_response_data) do
      { 'credential_id' => credential_id,
        'type' => type,
        'locked' => expected_lock_status }
    end
    let(:expected_response_log) do
      { credential_id:,
        type:,
        locked: expected_lock_status,
        requested_by: service_account_access_token.user_identifier }
    end

    context 'when a logingov uuid is requested' do
      let(:type) { 'logingov' }
      let(:credential_id) { logingov_user_verification.logingov_uuid }

      it_behaves_like 'when validating params and querying a UserVerification'
    end

    context 'when an idme uuid is requested' do
      let(:type) { 'idme' }
      let(:credential_id) { idme_user_verification.idme_uuid }

      it_behaves_like 'when validating params and querying a UserVerification'
    end

    context 'when a dslogon uuid is requested' do
      let(:type) { 'dslogon' }
      let(:credential_id) { dslogon_user_verification.dslogon_uuid }

      it_behaves_like 'when validating params and querying a UserVerification'
    end

    context 'when an mhv uuid is requested' do
      let(:type) { 'mhv' }
      let(:credential_id) { mhv_user_verification.mhv_uuid }

      it_behaves_like 'when validating params and querying a UserVerification'
    end
  end
end
