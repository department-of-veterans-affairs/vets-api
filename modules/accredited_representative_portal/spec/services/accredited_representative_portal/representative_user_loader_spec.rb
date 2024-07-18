# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::RepresentativeUserLoader do
  describe '#perform' do
    subject(:representative_user_loader) { described_class.new(access_token:, request_ip:) }

    let(:reloaded_user) { representative_user_loader.perform }

    let(:access_token) { create(:access_token, user_uuid: user.uuid, session_handle:) }
    let!(:user) do
      create(:representative_user, uuid: user_uuid, icn: user_icn, loa: user_loa)
    end
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

        it 'reloads user object with expected attributes' do
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

        context 'pilot_representatives' do
          let!(:ogc_registration_number) { '12300' }
          let!(:pilot_representative) do
            create(:pilot_representative, email: session.credential_email,
                                          ogc_registration_number:)
          end
          let!(:accredited_individual) do
            create(:accredited_individual, :with_organizations, registration_number: ogc_registration_number)
          end

          describe '#ogc_registration_number' do
            context 'when a matching pilot_representative is found' do
              it 'returns the OGC registration number' do
                expect(reloaded_user.ogc_registration_number).to eq(pilot_representative.ogc_registration_number)
              end
            end

            context 'when a pilot_representative record does not exist for the user' do
              let(:pilot_representative) { nil }

              it 'returns nil' do
                expect(reloaded_user.ogc_registration_number).to be_nil
              end
            end
          end

          describe '#poa_codes' do
            context 'when reloading a user' do
              it 'sets the poa_codes based on the ogc_registration_number on the accredited_individual' do
                expect(reloaded_user.poa_codes).to be_present
                expect(reloaded_user.poa_codes).to match_array(accredited_individual.poa_codes)
              end
            end

            context 'when a pilot_representative record does not exist for the user' do
              let(:pilot_representative) { nil }

              it 'returns nil' do
                expect(reloaded_user.poa_codes).to be_nil
              end
            end
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
