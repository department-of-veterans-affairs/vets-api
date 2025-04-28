# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::TokenResponseGenerator do
  subject(:generator) { described_class.new(params:, cookies:, request_attributes:) }

  let(:request_attributes) { { remote_ip: } }
  let(:remote_ip) { Faker::Internet.ip_v4_address }
  let(:cookies) { double('cookies') }

  before do
    allow(Rails.logger).to receive(:info)
  end

  describe '#perform' do
    context 'when grant_type is AUTH_CODE_GRANT' do
      let(:grant_type) { SignIn::Constants::Auth::AUTH_CODE_GRANT }
      let(:params) do
        {
          grant_type:,
          code: 'some-code',
          code_verifier: 'some-code-verifier',
          client_assertion: 'some-client-assertion',
          client_assertion_type: 'some-client-assertion-type',
          client_id: 'some-client-id'
        }
      end
      let(:access_token) { session_container.access_token }
      let(:validated_credential) { create(:validated_credential) }
      let(:user_verification) { validated_credential.user_verification }
      let(:session_container) { create(:session_container) }
      let(:code_validator) { instance_double(SignIn::CodeValidator, perform: validated_credential) }
      let(:session_creator) { instance_double(SignIn::SessionCreator, perform: session_container) }
      let(:token_serializer) { instance_double(SignIn::TokenSerializer, perform: expected_token_response) }
      let(:expected_token_response) do
        {
          data:
          {
            access_token:,
            refresh_token: 'some-refresh-token',
            anti_csrf_token: 'some-anti-csrf-token'
          }
        }
      end
      let(:expected_log_message) { '[SignInService] [SignIn::TokenResponseGenerator] session created' }

      before do
        allow(SignIn::CodeValidator).to receive(:new).and_return(code_validator)
        allow(SignIn::SessionCreator).to receive(:new).and_return(session_creator)
        allow(SignIn::TokenSerializer).to receive(:new).and_return(token_serializer)
      end

      it 'generates the expected response' do
        expect(subject.perform).to eq(expected_token_response)
      end

      it 'logs the expected message' do
        subject.perform
        expect(Rails.logger).to have_received(:info).with(expected_log_message, access_token.to_s)
      end

      context 'when UserAudit logger is called' do
        let(:event) { :sign_in }
        let(:user_account) { user_verification.user_account }
        let!(:user_action_event) { create(:user_action_event, identifier: event) }
        let(:icn) { user_account.icn }
        let(:user_agent) { Faker::Internet.user_agent }
        let(:expected_log_payload) do
          {
            event: :sign_in,
            user_verification_id: user_verification.id,
            status: :success
          }
        end
        let(:expected_log_tags) { { remote_ip:, user_agent: } }
        let(:expected_audit_log_message) do
          expected_log_payload.merge(acting_ip_address: remote_ip, acting_user_agent: user_agent).as_json
        end

        before do
          allow(SemanticLogger).to receive(:named_tags).and_return(expected_log_tags)
          allow(UserAudit.logger).to receive(:success).and_call_original
        end

        it 'creates a user audit log', skip: 'Flakey test' do
          expect { subject.perform }.to change(Audit::Log, :count).by(1)
          expect(UserAudit.logger).to have_received(:success).with(event:, user_verification:)
        end

        it 'creates a user action', skip: 'Flakey test' do
          expect { subject.perform }.to change(UserAction, :count).by(1)
          expect(UserAudit.logger).to have_received(:success).with(event: :sign_in, user_verification:)
        end
      end
    end

    context 'when grant_type is JWT_BEARER_GRANT' do
      let(:grant_type) { SignIn::Constants::Auth::JWT_BEARER_GRANT }
      let(:assertion) { 'some-assertion' }
      let(:params) do
        {
          grant_type:,
          assertion:
        }
      end

      let(:access_token) { 'some-access-token' }
      let(:encoded_access_token) { 'some-encoded-access-token' }
      let(:assertion_validator) { instance_double(SignIn::AssertionValidator, perform: access_token) }
      let(:jwt_encoder) { instance_double(SignIn::ServiceAccountAccessTokenJwtEncoder, perform: encoded_access_token) }
      let(:expected_response) do
        {
          data:
          {
            access_token: encoded_access_token
          }
        }
      end
      let(:expected_log_message) { '[SignInService] [SignIn::TokenResponseGenerator] generated service account token' }

      before do
        allow(SignIn::AssertionValidator).to receive(:new).and_return(assertion_validator)
        allow(SignIn::ServiceAccountAccessTokenJwtEncoder).to receive(:new).and_return(jwt_encoder)
      end

      it 'generates the expected response' do
        expect(subject.perform).to eq(expected_response)
      end

      it 'logs the expected message' do
        subject.perform
        expect(Rails.logger).to have_received(:info).with(expected_log_message, access_token)
      end
    end

    context 'when grant_type is TOKEN_EXCHANGE_GRANT' do
      let(:grant_type) { SignIn::Constants::Auth::TOKEN_EXCHANGE_GRANT }
      let(:params) do
        {
          grant_type:,
          subject_token: 'some-subject-token',
          actor_token: 'some-actor-token',
          actor_token_type: 'some-actor-token-type',
          client_id: 'some-client-id'

        }
      end
      let(:exchanged_container) { instance_double(SignIn::SessionContainer, access_token:) }
      let(:token_exchanger) { instance_double(SignIn::TokenExchanger, perform: exchanged_container) }
      let(:token_serializer) { instance_double(SignIn::TokenSerializer, perform: expected_token_response) }
      let(:expected_token_response) do
        {
          data:
          {
            access_token:,
            refresh_token: 'some-refresh-token',
            anti_csrf_token: 'some-anti-csrf-token'
          }
        }
      end
      let(:access_token) { 'some-access-token' }
      let(:expected_log_message) { '[SignInService] [SignIn::TokenResponseGenerator] token exchanged' }

      before do
        allow(SignIn::TokenExchanger).to receive(:new).and_return(token_exchanger)
        allow(SignIn::TokenSerializer).to receive(:new).and_return(token_serializer)
      end

      it 'generates the expected response' do
        expect(subject.perform).to eq(expected_token_response)
      end

      it 'logs the expected message' do
        subject.perform
        expect(Rails.logger).to have_received(:info).with(expected_log_message, access_token)
      end
    end

    context 'when grant_type is not valid' do
      let(:grant_type) { 'invalid_grant_type' }
      let(:params) { { grant_type: } }

      it 'raises a MalformedParamsError' do
        expect { subject.perform }.to raise_error(SignIn::Errors::MalformedParamsError, 'Grant type is not valid')
      end
    end
  end
end
