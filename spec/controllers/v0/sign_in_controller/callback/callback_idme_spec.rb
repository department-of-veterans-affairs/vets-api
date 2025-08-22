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
        let(:uplevel_state_value) do
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

          context 'when type in state JWT is idme' do
            let(:type) { SignIn::Constants::Auth::IDME }
            let(:idme_uuid) { 'some-idme-uuid' }
            let(:user_info) do
              OpenStruct.new(
                sub: idme_uuid,
                level_of_assurance:,
                credential_ial:,
                social: '123456789',
                birth_date: '2022-01-01',
                fname: 'some-name',
                lname: 'some-family-name',
                email: 'some-email'
              )
            end
            let(:mpi_profile) do
              build(:mpi_profile,
                    ssn: user_info.social,
                    birth_date: Formatters::DateFormatter.format_date(user_info.birth_date),
                    given_names: [user_info.fname],
                    family_name: user_info.lname)
            end
            let(:response) { OpenStruct.new(access_token: token) }
            let(:level_of_assurance) { LOA::THREE }
            let(:credential_ial) { LOA::IDME_CLASSIC_LOA3 }
            let(:token) { 'some-token' }

            before do
              allow_any_instance_of(SignIn::Idme::Service).to receive(:token).with(code_value).and_return(response)
              allow_any_instance_of(SignIn::Idme::Service).to receive(:user_info).with(token).and_return(user_info)
            end

            context 'and code is given that matches expected code for auth service' do
              let(:response) { OpenStruct.new(access_token: token) }
              let(:level_of_assurance) { LOA::THREE }

              context 'and credential should be uplevelled' do
                let(:acr) { 'min' }
                let(:credential_ial) { LOA::ONE }
                let(:expected_redirect_uri) { IdentitySettings.idme.redirect_uri }
                let(:expected_redirect_uri_param) { { redirect_uri: expected_redirect_uri }.to_query }

                before do
                  allow_any_instance_of(SignIn::StatePayloadJwtEncoder).to receive(:perform)
                    .and_return(uplevel_state_value)
                end

                it 'returns ok status' do
                  expect(subject).to have_http_status(:ok)
                end

                it 'renders expected redirect_uri in template' do
                  expect(subject.body).to match(expected_redirect_uri_param)
                end

                it 'generates a new state payload with a new StateCode' do
                  expect_any_instance_of(SignIn::StatePayloadJwtEncoder).to receive(:perform)
                  subject
                end

                it 'renders a new state' do
                  expect(subject.body).to match(uplevel_state_value)
                end
              end

              context 'and credential should not be uplevelled' do
                let(:acr) { 'loa3' }
                let(:ial) { 2 }
                let(:credential_ial) { LOA::IDME_CLASSIC_LOA3 }
                let(:client_code) { 'some-client-code' }
                let(:client_redirect_uri) { client_config.redirect_uri }
                let(:expected_log) { '[SignInService] [V0::SignInController] callback' }
                let(:statsd_callback_success) { SignIn::Constants::Statsd::STATSD_SIS_CALLBACK_SUCCESS }
                let(:authentication_time) { 0 }
                let(:expected_logger_context) do
                  {
                    type:,
                    client_id:,
                    ial:,
                    acr:,
                    icn: mpi_profile.icn,
                    credential_uuid: idme_uuid,
                    authentication_time:
                  }
                end
                let(:meta_refresh_tag) { '<meta http-equiv="refresh" content="0;' }

                before do
                  allow(SecureRandom).to receive(:uuid).and_return(client_code)
                end

                it 'returns ok status' do
                  expect(subject).to have_http_status(:ok)
                end

                it 'renders the oauth_get_form template with meta refresh tag' do
                  expect(subject.body).to include(meta_refresh_tag)
                end

                context 'and client configuration is configured to enforce terms of use' do
                  let(:enforced_terms) { SignIn::Constants::Auth::VA_TERMS }

                  context 'and the authenticated user has previously accepted terms of use' do
                    let!(:terms_of_use_agreement) { create(:terms_of_use_agreement, user_account:) }
                    let(:user_account) { user_verification.user_account }
                    let(:user_verification) { create(:idme_user_verification, idme_uuid:) }

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
            end
          end
        end
      end
    end
  end
end
