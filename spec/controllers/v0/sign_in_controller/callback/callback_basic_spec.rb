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
    let(:state_value) { 'some-state' }
    let(:code_value) { 'some-code' }
    let(:error_value) { 'some-error' }
    let(:statsd_tags) { ["type:#{type}", "client_id:#{client_id}", "ial:#{ial}", "acr:#{acr}"] }
    let(:type) {}
    let(:acr) { nil }
    let(:mpi_update_profile_response) { create(:add_person_response) }
    let(:mpi_add_person_response) { create(:add_person_response, parsed_codes: { icn: add_person_icn }) }
    let(:add_person_icn) { nil }
    let(:find_profile) { create(:find_profile_response, profile: mpi_profile) }
    let(:mpi_profile) { nil }
    let(:client_id) { client_config.client_id }
    let(:authentication) { SignIn::Constants::Auth::API }
    let!(:client_config) { create(:client_config, authentication:, enforced_terms:, terms_of_use_url:) }
    let(:enforced_terms) { nil }
    let(:terms_of_use_url) { 'some-terms-of-use-url' }

    before do
      allow(Rails.logger).to receive(:info)
      allow_any_instance_of(MPI::Service).to receive(:update_profile).and_return(mpi_update_profile_response)
      allow_any_instance_of(MPIData).to receive(:response_from_redis_or_service).and_return(find_profile)
      allow_any_instance_of(MPI::Service).to receive(:find_profile_by_identifier).and_return(find_profile)
      allow_any_instance_of(MPI::Service).to receive(:add_person_implicit_search).and_return(mpi_add_person_response)
    end

    context 'when error is not given' do
      let(:error) { {} }

      context 'when code is not given' do
        let(:code) { {} }
        let(:expected_error) { 'Code is not defined' }
        let(:client_id) { nil }

        it_behaves_like 'callback api based error response'
      end

      context 'when state is not given' do
        let(:state) { {} }
        let(:expected_error) { 'State is not defined' }
        let(:client_id) { nil }

        it_behaves_like 'callback api based error response'
      end

      context 'when state is arbitrary' do
        let(:state_value) { 'some-state' }
        let(:expected_error) { 'State JWT is malformed' }
        let(:client_id) { nil }

        it_behaves_like 'callback api based error response'
      end

      context 'when state is a JWT but with improper signature' do
        let(:state_value) { JWT.encode('some-state', private_key, encode_algorithm) }
        let(:private_key) { OpenSSL::PKey::RSA.new(2048) }
        let(:encode_algorithm) { SignIn::Constants::Auth::JWT_ENCODE_ALGORITHM }
        let(:expected_error) { 'State JWT body does not match signature' }
        let(:client_id) { nil }

        it_behaves_like 'callback api based error response'
      end

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
        let(:code_value) { 'some-code' }
        let(:response) { nil }

        context 'and code in state payload does not match an existing state code' do
          let(:expected_error) { 'Code in state is not valid' }
          let(:error_code) { SignIn::Constants::ErrorCode::INVALID_REQUEST }

          before { allow(SignIn::StateCode).to receive(:find).and_return(nil) }

          it_behaves_like 'callback error response'
        end
      end
    end

    context 'when error is given' do
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

      context 'and error is access denied value' do
        let(:error_value) { SignIn::Constants::Auth::ACCESS_DENIED }
        let(:expected_error) { 'User Declined to Authorize Client' }

        context 'and type from state is logingov' do
          let(:type) { SignIn::Constants::Auth::LOGINGOV }
          let(:error_code) { SignIn::Constants::ErrorCode::LOGINGOV_VERIFICATION_DENIED }

          it_behaves_like 'callback error response'
        end

        context 'and type from state is some other value' do
          let(:type) { SignIn::Constants::Auth::IDME }
          let(:error_code) { SignIn::Constants::ErrorCode::IDME_VERIFICATION_DENIED }

          it_behaves_like 'callback error response'
        end
      end

      context 'and error is an arbitrary value' do
        let(:error_value) { 'some-error-value' }
        let(:expected_error) { 'Unknown Credential Provider Issue' }
        let(:error_code) { SignIn::Constants::ErrorCode::GENERIC_EXTERNAL_ISSUE }

        it_behaves_like 'callback error response'
      end
    end
  end
end
