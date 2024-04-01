# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::RepresentativeUserLoader do
  describe '#perform' do
    subject(:representative_user_loader) { described_class.new(access_token:, request_ip:) }

    let(:access_token) { create(:access_token, user_uuid: user.uuid, session_handle:) }
    let!(:user) { create(:representative_user, uuid: user_uuid, icn: user_icn, loa: user_loa) }
    let(:user_uuid) { user_account.id }
    let(:user_account) { create(:user_account) }
    let(:user_verification) { create(:idme_user_verification, user_account:) }
    let(:user_loa) { { current: SignIn::Constants::Auth::LOA_THREE, highest: SignIn::Constants::Auth::LOA_THREE } }
    let(:user_icn) { user_account.icn }
    let(:session) { create(:oauth_session, user_account:, user_verification:) }
    let(:session_handle) { session.handle }
    let(:request_ip) { '123.456.78.90' }

    shared_examples 'reloaded user' do
      context 'and associated session cannot be found' do
        let(:session) { nil }
        let(:session_handle) { 'some-not-found-session-handle' }
        let(:expected_error) { SignIn::Errors::SessionNotFoundError }
        let(:expected_error_message) { 'Invalid Session Handle' }

        it 'raises a session not found error' do
          expect { representative_user_loader.perform }.to raise_error(expected_error, expected_error_message)
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
        let(:ssn) { Faker::Number.leading_zero_number(digits: 9).to_s }
        let(:birth_date) { '1987-10-17' }
        let(:mpi_profile) { build(:mpi_profile, { given_names: [user.first_name], family_name: user.last_name, ssn:, birth_date: }) }
        let(:profile_response) { create(:find_profile_response, profile: mpi_profile) }

        before do
          create(:representative, representative_attributes)
          allow_any_instance_of(MPI::Service).to receive(:find_profile_by_identifier).and_return(profile_response)
        end

        context 'and user is not a VA representative' do
          let(:representative_attributes) { {} }
          let(:expected_error) { AccreditedRepresentativePortal::Errors::RepresentativeRecordNotFoundError }
          let(:expected_error_message) { 'User is not a VA representative' }

          it 'raises a representative record not found error' do
            expect { representative_user_loader.perform }.to raise_error(expected_error, expected_error_message)
          end
        end

        context 'and user is a VA representative' do
          let(:representative_attributes) do
            { first_name: session.user_attributes_hash['first_name'],
              last_name: session.user_attributes_hash['last_name'],
              ssn: ssn, 
              dob: birth_date }
          end

          it 'reloads user object with expected attributes' do
            reloaded_user = representative_user_loader.perform

            expect(reloaded_user).to be_a(AccreditedRepresentativePortal::RepresentativeUser)
            expect(reloaded_user.uuid).to eq(user_uuid)
            expect(reloaded_user.email).to eq(email)
            expect(reloaded_user.first_name).to eq(session.user_attributes_hash['first_name'])
            expect(reloaded_user.last_name).to eq(session.user_attributes_hash['last_name'])
            expect(reloaded_user.icn).to eq(user_icn)
            expect(reloaded_user.idme_uuid).to eq(idme_uuid)
            expect(reloaded_user.logingov_uuid).to eq(nil)
            expect(reloaded_user.fingerprint).to eq(request_ip)
            expect(reloaded_user.last_signed_in).to eq(session.created_at)
            expect(reloaded_user.authn_context).to eq(authn_context)
            expect(reloaded_user.loa).to eq(user_loa)
            expect(reloaded_user.sign_in).to eq(sign_in)
          end
        end
      end
    end

    context 'when user record already exists in redis' do
      let(:user_uuid) { user_account.id }

      context 'and user identity record exists in redis' do
        it 'returns existing user redis record' do
          expect(representative_user_loader.perform.uuid).to eq(user_uuid)
        end
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
