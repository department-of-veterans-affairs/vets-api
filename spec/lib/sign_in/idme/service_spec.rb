# frozen_string_literal: true

require 'rails_helper'
require 'sign_in/idme/service'

describe SignIn::Idme::Service do
  let(:code) { '04e3f01f11764b50becb0cdcb618b804' }
  let(:token) do
    {
      access_token: '0f5ebddd60d0451782214e6705cac5d1',
      token_type: 'bearer',
      expires_in: 300,
      scope: 'http://idmanagement.gov/ns/assurance/loa/3',
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
        fname: first_name,
        social: ssn,
        lname: last_name,
        level_of_assurance: 3,
        multifactor: true,
        credential_aal: 2,
        credential_ial: 'classic_loa3',
        uuid: user_uuid
      }
    )
  end
  let(:expiration_time) { 1_652_159_422 }
  let(:current_time) { 1_652_141_421 }
  let(:idme_originating_url) { 'https://api.idmelabs.com/oidc' }
  let(:state) { 'some-state' }
  let(:idme_client_id) { 'ef7f1237ed3c396e4b4a2b04b608a7b1' }
  let(:user_uuid) { '6400bbf301eb4e6e95ccea7693eced6f' }
  let(:birth_date) { '1950-10-04' }
  let(:first_name) { 'MARK' }
  let(:last_name) { 'WEBB' }
  let(:ssn) { '796104437' }
  let(:email) { 'vets.gov.user+228@gmail.com' }

  before do
    Timecop.freeze(Time.zone.at(current_time))
  end

  after do
    Timecop.return
  end

  describe '#render_auth' do
    let(:response) { subject.render_auth(state: state).to_s }
    let(:configuration) { SignIn::Idme::Configuration }
    let(:expected_authorization_page) { "#{base_path}/#{auth_path}" }
    let(:base_path) { 'some-base-path' }
    let(:auth_path) { 'oauth/authorize' }

    before do
      allow(Settings.idme).to receive(:oauth_url).and_return(base_path)
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
      it 'returns an access token' do
        VCR.use_cassette('identity/idme_200_responses') do
          expect(subject.token(code)).to eq(token)
        end
      end
    end

    context 'when an issue occurs with the client request' do
      let(:expected_error) { Common::Client::Errors::ClientError }
      let(:expected_error_message) { 'Cannot perform Token request' }

      before do
        allow_any_instance_of(described_class).to receive(:perform).and_raise(Common::Client::Errors::ClientError)
      end

      it 'raises a client error with expected message' do
        expect { subject.token(code) }.to raise_error(expected_error, expected_error_message)
      end
    end
  end

  describe '#user_info' do
    it 'returns user attributes' do
      VCR.use_cassette('identity/idme_200_responses') do
        expect(subject.user_info(token)).to eq(user_info)
      end
    end

    context 'when an issue occurs with the client request' do
      let(:expected_error) { Common::Client::Errors::ClientError }
      let(:expected_error_message) { 'Cannot perform UserInfo request' }

      before do
        allow_any_instance_of(described_class).to receive(:perform).and_raise(Common::Client::Errors::ClientError)
      end

      it 'raises a client error with expected message' do
        expect { subject.user_info(token) }.to raise_error(expected_error, expected_error_message)
      end
    end

    context 'when an issue occurs with the JWE decryption' do
      let(:expected_error) { SignIn::Idme::Errors::JWEDecodeError }
      let(:expected_error_message) { 'JWE is malformed' }
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
      let(:expected_error_message) { 'JWT body does not match signature' }
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
      let(:expected_error_message) { 'JWT has expired' }

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
      let(:expected_error_message) { 'JWT is malformed' }

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
end
