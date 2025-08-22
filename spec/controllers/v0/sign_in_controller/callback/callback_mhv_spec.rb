# frozen_string_literal: true

require 'rails_helper'
require_relative '../sign_in_controller_shared_examples_spec'

RSpec.describe V0::SignInController, type: :controller do
  include_context 'callback_shared_setup'

  describe 'GET callback' do
    subject { get(:callback, params: {}.merge(code).merge(state).merge(error)) }

    let(:code) { { code: code_value } }
    let(:state) { { state: state_value } }
    let(:error) { { error: error_value } }
    let(:code_value) { 'some-code' }
    let(:error_value) { 'some-error' }
    let(:authentication) { SignIn::Constants::Auth::API }
    let!(:client_config) { create(:client_config, authentication:, enforced_terms:, terms_of_use_url:) }
    let(:enforced_terms) { nil }
    let(:terms_of_use_url) { 'some-terms-of-use-url' }
    let(:client_id) { client_config.client_id }
    let(:statsd_tags) { ["type:#{type}", "client_id:#{client_id}", "ial:#{ial}", "acr:#{acr}"] }
    let(:mpi_update_profile_response) { create(:add_person_response) }
    let(:mpi_add_person_response) { create(:add_person_response, parsed_codes: { icn: add_person_icn }) }
    let(:add_person_icn) { nil }
    let(:find_profile) { create(:find_profile_response, profile: mpi_profile) }
    let(:mpi_profile) { nil }

    before do
      allow(Rails.logger).to receive(:info)
      allow_any_instance_of(MPI::Service).to receive(:update_profile).and_return(mpi_update_profile_response)
      allow_any_instance_of(MPIData).to receive(:response_from_redis_or_service).and_return(find_profile)
      allow_any_instance_of(MPI::Service).to receive(:find_profile_by_identifier).and_return(find_profile)
      allow_any_instance_of(MPI::Service).to receive(:add_person_implicit_search).and_return(mpi_add_person_response)
    end

    context 'when error is not given' do
      let(:error) { {} }

      context 'when state is a proper, expected JWT' do
        let(:state_value) do
          SignIn::StatePayloadJwtEncoder.new(code_challenge:,
                                             code_challenge_method:,
                                             acr:,
                                             client_config:,
                                             type:,
                                             client_state:).perform
        end
        let(:code_challenge) { Base64.urlsafe_encode64('some-code-challenge') }
        let(:code_challenge_method) { SignIn::Constants::Auth::CODE_CHALLENGE_METHOD }
        let(:acr) { SignIn::Constants::Auth::ACR_VALUES.first }
        let(:type) { SignIn::Constants::Auth::CSP_TYPES.first }
        let(:client_state) { SecureRandom.alphanumeric(SignIn::Constants::Auth::CLIENT_STATE_MINIMUM_LENGTH) }

        context 'and code in state payload matches an existing state code' do
          before { Timecop.freeze }

          after { Timecop.return }

          context 'when type in state JWT is mhv' do
            let(:type) { SignIn::Constants::Auth::MHV }
            let(:backing_idme_uuid) { 'some-backing-idme-uuid' }
            let(:mhv_uuid) { 'some-mhv-uuid' }
            let(:user_info) do
              OpenStruct.new(
                sub: backing_idme_uuid,
                level_of_assurance:,
                credential_ial:,
                mhv_uuid:,
                mhv_icn:,
                mhv_assurance:,
                email: 'some-email'
              )
            end
            let(:mhv_icn) { '987654321V123456' }
            let(:add_person_icn) { mhv_icn }
            let(:response) { OpenStruct.new(access_token: token) }
            let(:level_of_assurance) { LOA::THREE }
            let(:credential_ial) { LOA::IDME_CLASSIC_LOA3 }
            let(:token) { 'some-token' }
            let(:mhv_assurance) { 'some-mhv-assurance' }
            let(:mpi_profile) do
              build(:mpi_profile,
                    icn: user_info.mhv_icn,
                    mhv_ids: [user_info.mhv_uuid])
            end

            before do
              allow_any_instance_of(SignIn::Idme::Service).to receive(:token).with(code_value).and_return(response)
              allow_any_instance_of(SignIn::Idme::Service).to receive(:user_info).with(token).and_return(user_info)
            end

            context 'and code is given that matches expected code for auth service' do
              let(:response) { OpenStruct.new(access_token: token) }
              let(:level_of_assurance) { LOA::THREE }
              let(:acr) { SignIn::Constants::Auth::MIN }
              let(:ial) { IAL::TWO }
              let(:credential_ial) { LOA::IDME_CLASSIC_LOA3 }
              let(:client_code) { 'some-client-code' }
              let(:client_redirect_uri) { client_config.redirect_uri }
              let(:expected_log) { '[SignInService] [V0::SignInController] callback' }
              let(:statsd_callback_success) { SignIn::Constants::Statsd::STATSD_SIS_CALLBACK_SUCCESS }
              let(:expected_icn) { mpi_profile.icn }
              let(:authentication_time) { 0 }
              let(:expected_logger_context) do
                {
                  type:,
                  client_id:,
                  ial:,
                  acr:,
                  icn: expected_icn,
                  credential_uuid: backing_idme_uuid,
                  authentication_time:
                }
              end
              let(:meta_refresh_tag) { '<meta http-equiv="refresh" content="0;' }

              before do
                allow(SecureRandom).to receive(:uuid).and_return(client_code)
              end

              shared_context 'mhv successful callback' do
                it 'returns ok status' do
                  expect(subject).to have_http_status(:ok)
                end

                it 'renders the oauth_get_form template with meta refresh tag' do
                  expect(subject.body).to include(meta_refresh_tag)
                end

                it 'directs to the given redirect url set in the client configuration' do
                  expect(subject.body).to include(client_redirect_uri)
                end

                it 'includes expected code param' do
                  expect(subject.body).to include(client_code)
                end

                it 'includes expected state param' do
                  expect(subject.body).to include(client_state)
                end

                it 'includes expected type param' do
                  expect(subject.body).to include(type)
                end

                it 'logs the successful callback' do
                  expect(Rails.logger).to receive(:info).with(expected_log, expected_logger_context)
                  expect { subject }.to trigger_statsd_increment(statsd_callback_success, tags: statsd_tags)
                end
              end

              context 'and mhv account is not premium' do
                let(:mhv_assurance) { 'some-mhv-assurance' }
                let(:ial) { IAL::ONE }
                let(:expected_icn) { nil }

                it_behaves_like 'mhv successful callback'
              end

              context 'and mhv account is premium' do
                let(:mhv_assurance) { 'Premium' }
                let(:ial) { IAL::TWO }

                it_behaves_like 'mhv successful callback'

                context 'and client configuration is configured to enforce terms of use' do
                  let(:enforced_terms) { SignIn::Constants::Auth::VA_TERMS }

                  context 'and the authenticated user has previously accepted terms of use' do
                    let!(:terms_of_use_agreement) { create(:terms_of_use_agreement, user_account:) }
                    let(:user_account) { user_verification.user_account }
                    let(:user_verification) { create(:mhv_user_verification, mhv_uuid:, backing_idme_uuid:) }

                    it 'directs to the given redirect url set in the client configuration' do
                      expect(subject.body).to include(client_redirect_uri)
                    end
                  end

                  context 'and the authenticated user has not previously accepted terms of use' do
                    let(:terms_of_use_redirect_uri) { "#{terms_of_use_url}?#{embedded_params}" }
                    let(:embedded_params) { { redirect_url: client_redirect_uri }.to_query }

                    it 'directs to the terms of use url and embeds redirect url set in the client configuration' do
                      expect(subject.body).to include(terms_of_use_redirect_uri)
                    end
                  end
                end

                context 'and client configuration is not configured to enforce terms of use' do
                  let(:enforced_terms) { nil }

                  it 'directs to the given redirect url set in the client configuration' do
                    expect(subject.body).to include(client_redirect_uri)
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
