# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::UserLoader do
  describe '#perform' do
    subject { SignIn::UserLoader.new(access_token:, request_ip:).perform }

    let(:access_token) { create(:access_token, user_uuid: user.uuid, session_handle:) }
    let!(:user) do
      create(:user, :loa3, uuid: user_uuid, loa: user_loa, icn: user_icn, session_handle: user_session_handle,
                           needs_accepted_terms_of_use:)
    end
    let(:user_uuid) { user_account.id }
    let(:user_account) { create(:user_account) }
    let(:user_verification) { create(:idme_user_verification, user_account:) }
    let(:user_loa) { { current: SignIn::Constants::Auth::LOA_THREE, highest: SignIn::Constants::Auth::LOA_THREE } }
    let(:user_icn) { user_account.icn }
    let(:session) { create(:oauth_session, user_account:, user_verification:) }
    let(:session_handle) { session.handle }
    let(:user_session_handle) { session_handle }
    let(:request_ip) { '123.456.78.90' }
    let(:vha_facility_ids) { %w[450MH] }
    let(:needs_accepted_terms_of_use) { false }
    let!(:terms_of_use_agreement) do
      create(:terms_of_use_agreement, user_account:, response: tou_response)
    end
    let(:tou_response) { 'accepted' }

    shared_examples 'reloaded user' do
      context 'and associated session cannot be found' do
        let(:session) { nil }
        let(:session_handle) { 'some-not-found-session-handle' }
        let(:expected_error) { SignIn::Errors::SessionNotFoundError }
        let(:expected_error_message) { 'Invalid Session Handle' }

        it 'raises a session not found error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end

      context 'and associated session exists' do
        let(:session) do
          create(:oauth_session, client_id:, user_account:, user_verification:)
        end
        let(:edipi) { 'some-mpi-edipi' }
        let(:idme_uuid) { user_verification.idme_uuid }
        let(:email) { session.credential_email }
        let(:authn_context) { SignIn::Constants::Auth::IDME_LOA3 }
        let(:service_name) { user_verification.credential_type }
        let(:multifactor) { true }
        let(:client_config) { create(:client_config) }
        let(:client_id) { client_config.client_id }
        let(:auth_broker) { SignIn::Constants::Auth::BROKER_CODE }
        let(:sign_in) do
          { service_name:,
            auth_broker:,
            client_id: }
        end

        before do
          stub_mpi(build(:mpi_profile, edipi:, icn: user_icn, vha_facility_ids:))
        end

        context 'and user is authenticated with dslogon' do
          let(:user_verification) { create(:dslogon_user_verification, user_account:) }

          it 'reloads user object with expected backing idme uuid' do
            expect(subject.idme_uuid).to eq user_verification.backing_idme_uuid
          end
        end

        context 'and user is authenticated with mhv' do
          let(:user_verification) { create(:mhv_user_verification, user_account:) }

          it 'reloads user object with expected backing idme uuid' do
            expect(subject.idme_uuid).to eq user_verification.backing_idme_uuid
          end
        end

        it 'reloads user object with expected attributes' do
          reloaded_user = subject

          expect(reloaded_user.uuid).to eq(user_uuid)
          expect(reloaded_user.loa).to eq(user_loa)
          expect(reloaded_user.mhv_icn).to eq(user_icn)
          expect(reloaded_user.idme_uuid).to eq(idme_uuid)
          expect(reloaded_user.last_signed_in).to eq(session.created_at)
          expect(reloaded_user.email).to eq(email)
          expect(reloaded_user.authn_context).to eq(authn_context)
          expect(reloaded_user.identity_sign_in).to eq(sign_in)
          expect(reloaded_user.multifactor).to eq(multifactor)
          expect(reloaded_user.fingerprint).to eq(request_ip)
        end

        it 'reloads user object so that MPI can be called for additional attributes' do
          expect(subject.edipi).to be edipi
        end

        context 'when the user can create MHV account' do
          let(:enabled) { true }

          before do
            allow(MHV::AccountCreatorJob).to receive(:perform_async)
            allow(Flipper).to receive(:enabled?).with(:mhv_account_creation_after_login,
                                                      user_account).and_return(enabled)
          end

          it 'enqueues an MHV::AccountCreatorJob' do
            subject
            expect(MHV::AccountCreatorJob).to have_received(:perform_async).with(user_verification.id)
          end
        end
      end
    end

    context 'when user record already exists in redis' do
      let(:user_uuid) { user_account.id }

      context 'and user identity record exists in redis' do
        context 'and session handle on access token matches session handle on user record' do
          it 'returns existing user redis record' do
            expect(subject.uuid).to eq(user_uuid)
          end
        end

        context 'and session handle on access token does not match session handle on user record' do
          let(:user_session_handle) { 'some-user-session-handle' }

          it_behaves_like 'reloaded user'
        end
      end

      context 'and user identity record does not exist in redis' do
        before { UserIdentity.find(user_uuid).destroy }

        it_behaves_like 'reloaded user'
      end
    end

    context 'when user record no longer exists in redis' do
      before do
        user.destroy
      end

      it_behaves_like 'reloaded user'
    end
  end
end
