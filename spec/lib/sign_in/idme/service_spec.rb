# frozen_string_literal: true

require 'rails_helper'
require 'sign_in/idme/service'

describe SignIn::Idme::Service do
  let(:code) { '04e3f01f11764b50becb0cdcb618b804' }
  let(:scope) { 'http://idmanagement.gov/ns/assurance/loa/3' }
  let(:token) do
    {
      access_token: '0f5ebddd60d0451782214e6705cac5d1',
      token_type: 'bearer',
      expires_in: 300,
      scope:,
      refresh_token: '26f282c510a740bb9c27aeed65fc08c4',
      refresh_expires_in: 604_800
    }
  end
  let(:user_info) do
    OpenStruct.new(
      {
        iss: idme_originating_url,
        sub: user_uuid,
        aud: idme_client_id,
        exp: expiration_time,
        iat: current_time,
        credential_aal_highest: 2,
        credential_ial_highest: 'classic_loa3',
        birth_date:,
        email:,
        street:,
        zip:,
        state: address_state,
        city:,
        phone:,
        fname: first_name,
        social: ssn,
        lname: last_name,
        level_of_assurance: 3,
        multifactor:,
        credential_aal: 2,
        credential_ial: 'classic_loa3',
        uuid: user_uuid
      }
    )
  end

  let(:street) { '145 N Hayden Bay Dr Apt 2350' }
  let(:zip) { '97217' }
  let(:address_state) { 'OR' }
  let(:city) { 'Portland' }
  let(:expiration_time) { 1_666_827_002 }
  let(:current_time) { 1_666_809_002 }
  let(:idme_originating_url) { 'https://api.idmelabs.com/oidc' }
  let(:state) { 'some-state' }
  let(:acr) { 'some-acr' }
  let(:idme_client_id) { 'ef7f1237ed3c396e4b4a2b04b608a7b1' }
  let(:user_uuid) { '7e9bdcc2c79247fda1e4973e24c9dcaf' }
  let(:birth_date) { '1970-10-10' }
  let(:phone) { '12069827345' }
  let(:multifactor) { true }
  let(:first_name) { 'Gary' }
  let(:last_name) { 'Twinkle' }
  let(:ssn) { '666798234' }
  let(:email) { 'tumults-vicious-0q@icloud.com' }
  let(:operation) { 'some-operation' }

  before do
    Timecop.freeze(Time.zone.at(current_time))
  end

  after do
    Timecop.return
  end

  describe '#render_auth' do
    let(:response) { subject.render_auth(state:, acr:, operation:).to_s }
    let(:expected_authorization_page) { "#{base_path}/#{auth_path}" }
    let(:base_path) { 'some-base-path' }
    let(:auth_path) { 'oauth/authorize' }
    let(:expected_log) do
      "[SignIn][Idme][Service] Rendering auth, state: #{state}, acr: #{acr}, operation: #{operation}"
    end

    before do
      allow(Settings.idme).to receive(:oauth_url).and_return(base_path)
    end

    it 'logs information to rails logger' do
      expect(Rails.logger).to receive(:info).with(expected_log)
      response
    end

    it 'renders the expected redirect uri' do
      expect(response).to include(expected_authorization_page)
    end

    context 'when operation parameter equals Constants::Auth::SIGN_UP' do
      let(:operation) { SignIn::Constants::Auth::SIGN_UP }
      let(:expected_signup_param) { 'op=signup' }

      it 'includes op=signup param in rendered form' do
        expect(response).to include(expected_signup_param)
      end
    end

    context 'when operation is arbitrary' do
      let(:operation) { 'some-operation' }
      let(:expected_signup_param) { 'op=signup' }

      it 'does not include op=signup param in rendered form' do
        expect(response).not_to include(expected_signup_param)
      end
    end
  end

  describe '#token' do
    context 'when the request is successful' do
      let(:expected_log) { "[SignIn][Idme][Service] Token Success, code: #{code}, scope: #{scope}" }

      it 'logs information to rails logger' do
        VCR.use_cassette('identity/idme_200_responses') do
          expect(Rails.logger).to receive(:info).with(expected_log)
          subject.token(code)
        end
      end

      it 'returns an access token' do
        VCR.use_cassette('identity/idme_200_responses') do
          expect(subject.token(code)).to eq(token)
        end
      end
    end

    context 'when an issue occurs with the client request' do
      let(:expected_error) { Common::Client::Errors::ClientError }
      let(:expected_error_message) do
        "[SignIn][Idme][Service] Cannot perform Token request, status: #{status}, description: #{description}"
      end
      let(:status) { 'some-status' }
      let(:description) { 'some-description' }
      let(:raised_error) { Common::Client::Errors::ClientError.new(nil, status, { error_description: description }) }

      before do
        allow_any_instance_of(described_class).to receive(:perform).and_raise(raised_error)
      end

      it 'raises a client error with expected message' do
        expect { subject.token(code) }.to raise_error(expected_error, expected_error_message)
      end
    end
  end

  describe '#user_info' do
    let(:test_client_cert_path) { 'spec/fixtures/sign_in/oauth_test.crt' }
    let(:test_client_key_path) { 'spec/fixtures/sign_in/oauth_test.key' }
    let(:expected_jwks_fetch_log) { '[SignIn][Idme][Service] Get Public JWKs Success' }

    before do
      allow(Settings.idme).to receive_messages(client_cert_path: test_client_cert_path,
                                               client_key_path: test_client_key_path)
    end

    it 'returns user attributes', vcr: { cassette_name: 'identity/idme_200_responses' } do
      expect(subject.user_info(token)).to eq(user_info)
    end

    context 'when log_credential is enabled in idme configuration' do
      before do
        allow_any_instance_of(SignIn::Idme::Configuration).to receive(:log_credential).and_return(true)
        allow(MockedAuthentication::Mockdata::Writer).to receive(:save_credential)
      end

      it 'makes a call to mocked authentication writer to save the credential',
         vcr: { cassette_name: 'identity/idme_200_responses' } do
        expect(MockedAuthentication::Mockdata::Writer).to receive(:save_credential)
        subject.user_info(token)
      end
    end

    context 'when an issue occurs with the client request' do
      let(:expected_error) { Common::Client::Errors::ClientError }
      let(:expected_error_message) do
        "[SignIn][Idme][Service] Cannot perform UserInfo request, status: #{status}, description: #{description}"
      end
      let(:status) { 'some-status' }
      let(:description) { 'some-description' }
      let(:raised_error) { Common::Client::Errors::ClientError.new(nil, status, { error_description: description }) }

      before do
        allow_any_instance_of(described_class).to receive(:perform).and_raise(raised_error)
      end

      it 'raises a client error with expected message' do
        expect { subject.user_info(token) }.to raise_error(expected_error, expected_error_message)
      end
    end

    context 'when the JWT has expired' do
      let(:current_time) { expiration_time + 100 }
      let(:expected_error) { SignIn::Idme::Errors::JWTExpiredError }
      let(:expected_error_message) { '[SignIn][Idme][Service] JWT has expired' }

      it 'raises a jwe expired error with expected message', vcr: { cassette_name: 'identity/idme_200_responses' } do
        expect { subject.user_info(token) }.to raise_error(expected_error, expected_error_message)
      end
    end

    context 'when an issue occurs with the JWE decryption' do
      let(:expected_error) { SignIn::Idme::Errors::JWEDecodeError }
      let(:expected_error_message) { '[SignIn][Idme][Service] JWE is malformed' }
      let(:malformed_jwe) { OpenStruct.new({ body: 'some-malformed-jwe'.to_json }) }

      before do
        allow_any_instance_of(described_class).to receive(:perform).and_return(malformed_jwe)
      end

      it 'raises a jwe decode error with expected message' do
        expect { subject.user_info(token) }.to raise_error(expected_error, expected_error_message)
      end
    end

    context 'when the JWT decoding does not match expected verification' do
      let(:expected_error) { SignIn::Idme::Errors::JWTVerificationError }
      let(:expected_error_message) { '[SignIn][Idme][Service] JWT body does not match signature' }

      it 'raises a jwe decode error with expected message',
         vcr: { cassette_name: 'identity/idme_jwks_mismatched_signature' } do
        expect { subject.user_info(token) }.to raise_error(expected_error, expected_error_message)
      end
    end

    context 'when the JWT is malformed' do
      let(:expected_error) { SignIn::Idme::Errors::JWTDecodeError }
      let(:expected_error_message) { '[SignIn][Idme][Service] JWT is malformed' }

      it 'raises a jwt malformed error with expected message',
         vcr: { cassette_name: 'identity/idme_jwks_jwt_malformed' } do
        expect { subject.user_info(token) }.to raise_error(expected_error, expected_error_message)
      end
    end

    context 'when the JWK is malformed' do
      let(:expected_error) { SignIn::Idme::Errors::PublicJWKError }
      let(:expected_error_message) { '[SignIn][Idme][Service] Public JWK is malformed' }

      it 'raises a jwt malformed error with expected message', vcr: { cassette_name: 'identity/idme_jwks_malformed' } do
        expect { subject.user_info(token) }.to raise_error(expected_error, expected_error_message)
      end
    end

    context 'when the public JWK response is not cached' do
      it 'logs information to rails logger' do
        VCR.use_cassette('identity/idme_200_responses') do
          expect(Rails.logger).to receive(:info).with(expected_jwks_fetch_log)
          subject.user_info(token)
        end
      end
    end

    context 'when the public JWKs response is cached' do
      let(:cache_key) { 'idme_public_jwks' }
      let(:cache_expiration) { 30.minutes }
      let(:response) { double(body: 'some-body') }
      let(:redis_store) { ActiveSupport::Cache::RedisCacheStore.new(redis: MockRedis.new) }

      before do
        allow(Rails).to receive(:cache).and_return(redis_store)
        Rails.cache.clear
        allow(Rails.logger).to receive(:info)
      end

      after do
        Rails.cache.clear
      end

      it 'uses the cached JWK response' do
        VCR.use_cassette('identity/idme_200_responses') do
          subject.user_info(token)
          expect(Rails.logger).to have_received(:info).with(expected_jwks_fetch_log)
        end

        VCR.use_cassette('identity/idme_200_responses') do
          subject.user_info(token)
          expect(Rails.logger).not_to receive(:info).with(expected_jwks_fetch_log)
        end
      end

      context 'when the JWK is not found in the cached JWKs' do
        let(:rsa_key) { OpenSSL::PKey::RSA.new(2048) }
        let(:jwks) { JWT::JWK::Set.new([JWT::JWK::RSA.new(rsa_key)]) }
        let(:expected_jwk_reload_log) { '[SignIn][Idme][Service] JWK not found, reloading public JWKs' }

        before do
          allow(Rails.cache).to receive(:delete_matched).and_call_original
        end

        it 'clears the cache and fetches the public JWKs again' do
          Rails.cache.write(cache_key, jwks, expires_in: cache_expiration)

          VCR.use_cassette('identity/idme_200_responses') do
            subject.user_info(token)

            expect(Rails.cache).to have_received(:delete_matched).with(cache_key)
            expect(Rails.logger).to have_received(:info).with(expected_jwk_reload_log)
            expect(Rails.logger).to have_received(:info).with(expected_jwks_fetch_log)
            expect(Rails.cache.read(cache_key)).not_to eq(jwks)
          end
        end
      end
    end
  end

  describe '#normalized_attributes' do
    before { subject.type = type }

    let(:expected_standard_attributes) do
      {
        idme_uuid: user_uuid,
        current_ial: SignIn::Constants::Auth::IAL_TWO,
        max_ial: SignIn::Constants::Auth::IAL_TWO,
        service_name:,
        csp_email: email,
        multifactor:,
        authn_context:,
        auto_uplevel:
      }
    end
    let(:service_name) { SignIn::Constants::Auth::IDME }
    let(:auto_uplevel) { false }
    let(:authn_context) { SignIn::Constants::Auth::IDME_LOA3 }
    let(:auth_broker) { SignIn::Constants::Auth::BROKER_CODE }
    let(:credential_level) do
      create(:credential_level, current_ial: SignIn::Constants::Auth::IAL_TWO,
                                max_ial: SignIn::Constants::Auth::IAL_TWO)
    end

    context 'when type is idme' do
      let(:type) { SignIn::Constants::Auth::IDME }
      let(:service_name) { SignIn::Constants::Auth::IDME }
      let(:user_info) do
        OpenStruct.new(
          {
            iss: idme_originating_url,
            sub: user_uuid,
            aud: idme_client_id,
            exp: expiration_time,
            iat: current_time,
            credential_aal_highest: 2,
            credential_ial_highest: 'classic_loa3',
            birth_date:,
            email:,
            fname: first_name,
            social: ssn,
            lname: last_name,
            street:,
            zip:,
            state: address_state,
            city:,
            level_of_assurance: 3,
            multifactor:,
            credential_aal: 2,
            credential_ial: 'classic_loa3',
            uuid: user_uuid
          }
        )
      end
      let(:expected_address) do
        {
          street:,
          postal_code: zip,
          state: address_state,
          city:,
          country:
        }
      end
      let(:country) { 'USA' }
      let(:expected_attributes) do
        expected_standard_attributes.merge({ ssn:,
                                             birth_date:,
                                             first_name:,
                                             last_name:,
                                             address: expected_address })
      end

      it 'returns expected idme attributes' do
        expect(subject.normalized_attributes(user_info, credential_level)).to eq(expected_attributes)
      end

      context 'and at least one field in address is not defined' do
        let(:street) { nil }

        it 'does not return an address object' do
          expect(subject.normalized_attributes(user_info, credential_level)[:address]).to eq(nil)
        end
      end
    end

    context 'when type is dslogon' do
      let(:type) { SignIn::Constants::Auth::DSLOGON }
      let(:authn_context) { SignIn::Constants::Auth::IDME_DSLOGON_LOA3 }
      let(:service_name) { SignIn::Constants::Auth::DSLOGON }
      let(:user_info) do
        OpenStruct.new(
          {
            iss: idme_originating_url,
            sub: user_uuid,
            aud: idme_client_id,
            exp: expiration_time,
            iat: current_time,
            credential_aal_highest: 2,
            credential_ial_highest: 'classic_loa3',
            dslogon_birth_date: birth_date,
            email:,
            dslogon_uuid: edipi,
            dslogon_fname: first_name,
            dslogon_idvalue: ssn,
            dslogon_lname: last_name,
            dslogon_mname: middle_name,
            level_of_assurance: 3,
            multifactor:,
            credential_aal: 2,
            credential_ial: 'classic_loa3',
            uuid: user_uuid
          }
        )
      end
      let(:middle_name) { 'some-middle-name' }
      let(:edipi) { 'some-edipi' }
      let(:expected_attributes) do
        expected_standard_attributes.merge({ ssn:,
                                             birth_date:,
                                             first_name:,
                                             middle_name:,
                                             last_name:,
                                             edipi: })
      end

      it 'returns expected dslogon attributes' do
        expect(subject.normalized_attributes(user_info, credential_level)).to eq(expected_attributes)
      end
    end

    context 'when type is mhv' do
      let(:type) { SignIn::Constants::Auth::MHV }
      let(:authn_context) { SignIn::Constants::Auth::IDME_MHV_LOA3 }
      let(:service_name) { SignIn::Constants::Auth::MHV }
      let(:user_info) do
        OpenStruct.new(
          {
            iss: idme_originating_url,
            sub: user_uuid,
            aud: idme_client_id,
            exp: expiration_time,
            iat: current_time,
            credential_aal_highest: 2,
            credential_ial_highest: 'classic_loa3',
            email:,
            mhv_uuid: mhv_correlation_id,
            mhv_icn:,
            mhv_assurance:,
            level_of_assurance: 3,
            multifactor:,
            credential_aal: 2,
            credential_ial: 'classic_loa3',
            uuid: user_uuid
          }
        )
      end
      let(:mhv_correlation_id) { 'some-mhv-correlation-id' }
      let(:mhv_icn) { 'some-mhv-icn' }
      let(:mhv_assurance) { 'some-mhv-assurance' }
      let(:expected_attributes) do
        expected_standard_attributes.merge({ mhv_icn:,
                                             mhv_correlation_id:,
                                             mhv_assurance: })
      end

      it 'returns expected mhv attributes' do
        expect(subject.normalized_attributes(user_info, credential_level)).to eq(expected_attributes)
      end
    end
  end
end
