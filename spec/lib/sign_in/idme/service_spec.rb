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
      scope: scope,
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
        birth_date: birth_date,
        email: email,
        street: street,
        zip: zip,
        state: address_state,
        city: city,
        phone: phone,
        fname: first_name,
        social: ssn,
        lname: last_name,
        level_of_assurance: 3,
        multifactor: multifactor,
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

  before do
    Timecop.freeze(Time.zone.at(current_time))
  end

  after do
    Timecop.return
  end

  describe '#render_auth' do
    let(:response) { subject.render_auth(state: state, acr: acr).to_s }
    let(:configuration) { SignIn::Idme::Configuration }
    let(:expected_authorization_page) { "#{base_path}/#{auth_path}" }
    let(:base_path) { 'some-base-path' }
    let(:auth_path) { 'oauth/authorize' }
    let(:expected_log) { "[SignIn][Idme][Service] Rendering auth, state: #{state}, acr: #{acr}" }

    before do
      allow(Settings.idme).to receive(:oauth_url).and_return(base_path)
    end

    it 'logs information to rails logger' do
      expect(Rails.logger).to receive(:info).with(expected_log)
      response
    end

    it 'renders the oauth_get_form template' do
      expect(response).to include('form id="oauth-form"')
    end

    it 'directs to the Id.me OAuth authorization page' do
      expect(response).to include("action=\"#{expected_authorization_page}\"")
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

    before do
      allow(Settings.idme).to receive(:client_cert_path).and_return(test_client_cert_path)
      allow(Settings.idme).to receive(:client_key_path).and_return(test_client_key_path)
    end

    it 'returns user attributes' do
      VCR.use_cassette('identity/idme_200_responses') do
        expect(subject.user_info(token)).to eq(user_info)
      end
    end

    context 'when log_credential is enabled in idme configuration' do
      before do
        allow_any_instance_of(SignIn::Idme::Configuration).to receive(:log_credential).and_return(true)
        allow(MockedAuthentication::Mockdata::Writer).to receive(:save_credential)
      end

      it 'makes a call to mocked authentication writer to save the credential' do
        VCR.use_cassette('identity/idme_200_responses') do
          expect(MockedAuthentication::Mockdata::Writer).to receive(:save_credential)
          subject.user_info(token)
        end
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
      let(:mismatched_public_key) { OpenSSL::PKey::RSA.generate(2048) }
      let(:idme_configuration) { SignIn::Idme::Configuration }

      before do
        allow_any_instance_of(idme_configuration).to receive(:jwt_decode_public_key).and_return(mismatched_public_key)
      end

      it 'raises a jwe decode error with expected message' do
        VCR.use_cassette('identity/idme_200_responses') do
          expect { subject.user_info(token) }.to raise_error(expected_error, expected_error_message)
        end
      end
    end

    context 'when the JWT has expired' do
      let(:current_time) { expiration_time + 100 }
      let(:expected_error) { SignIn::Idme::Errors::JWTExpiredError }
      let(:expected_error_message) { '[SignIn][Idme][Service] JWT has expired' }

      it 'raises a jwe expired error with expected message' do
        VCR.use_cassette('identity/idme_200_responses') do
          expect { subject.user_info(token) }.to raise_error(expected_error, expected_error_message)
        end
      end
    end

    context 'when the JWT is malformed' do
      let(:current_time) { expiration_time + 100 }
      let(:jwt_decode_error) { JWT::DecodeError }
      let(:expected_error) { SignIn::Idme::Errors::JWTDecodeError }
      let(:expected_error_message) { '[SignIn][Idme][Service] JWT is malformed' }

      before do
        allow(JWT).to receive(:decode).and_raise(jwt_decode_error)
      end

      it 'raises a jwt malformed error with expected message' do
        VCR.use_cassette('identity/idme_200_responses') do
          expect { subject.user_info(token) }.to raise_error(expected_error, expected_error_message)
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
        service_name: service_name,
        csp_email: email,
        multifactor: multifactor,
        authn_context: authn_context,
        auto_uplevel: auto_uplevel
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
            birth_date: birth_date,
            email: email,
            fname: first_name,
            social: ssn,
            lname: last_name,
            street: street,
            zip: zip,
            state: address_state,
            city: city,
            level_of_assurance: 3,
            multifactor: multifactor,
            credential_aal: 2,
            credential_ial: 'classic_loa3',
            uuid: user_uuid
          }
        )
      end
      let(:expected_address) do
        {
          street: street,
          postal_code: zip,
          state: address_state,
          city: city,
          country: country
        }
      end
      let(:country) { 'USA' }
      let(:expected_attributes) do
        expected_standard_attributes.merge({ ssn: ssn,
                                             birth_date: birth_date,
                                             first_name: first_name,
                                             last_name: last_name,
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
            email: email,
            dslogon_uuid: edipi,
            dslogon_fname: first_name,
            dslogon_idvalue: ssn,
            dslogon_lname: last_name,
            dslogon_mname: middle_name,
            level_of_assurance: 3,
            multifactor: multifactor,
            credential_aal: 2,
            credential_ial: 'classic_loa3',
            uuid: user_uuid
          }
        )
      end
      let(:middle_name) { 'some-middle-name' }
      let(:edipi) { 'some-edipi' }
      let(:expected_attributes) do
        expected_standard_attributes.merge({ ssn: ssn,
                                             birth_date: birth_date,
                                             first_name: first_name,
                                             middle_name: middle_name,
                                             last_name: last_name,
                                             edipi: edipi })
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
            email: email,
            mhv_uuid: mhv_correlation_id,
            mhv_icn: mhv_icn,
            mhv_assurance: mhv_assurance,
            level_of_assurance: 3,
            multifactor: multifactor,
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
        expected_standard_attributes.merge({ mhv_icn: mhv_icn,
                                             mhv_correlation_id: mhv_correlation_id,
                                             mhv_assurance: mhv_assurance })
      end

      it 'returns expected mhv attributes' do
        expect(subject.normalized_attributes(user_info, credential_level)).to eq(expected_attributes)
      end
    end
  end
end
