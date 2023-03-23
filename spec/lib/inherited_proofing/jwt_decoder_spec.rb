# frozen_string_literal: true

require 'rails_helper'
require 'inherited_proofing/jwt_decoder'

RSpec.describe InheritedProofing::JwtDecoder do
  describe '#perform' do
    subject do
      InheritedProofing::JwtDecoder.new(access_token_jwt:).perform
    end

    let(:access_token_jwt) { JWT.encode(payload, private_key, jwt_encode_algorithm) }
    let(:jwt_encode_algorithm) { InheritedProofing::JwtDecoder::JWT_ENCODE_ALGORITHM }
    let(:private_key) { OpenSSL::PKey::RSA.new(512) }
    let(:public_key) { private_key.public_key }
    let(:payload) { { inherited_proofing_auth: auth_code, exp: expiration_time.to_i } }
    let(:expiration_time) { Time.zone.now + 5.minutes }
    let(:auth_code) { 'some-auth-code' }

    before do
      allow_any_instance_of(InheritedProofing::JwtDecoder).to receive(:public_key).and_return(public_key)
    end

    context 'when access token jwt is expired' do
      let(:expiration_time) { Time.zone.now - 1.day }
      let(:expected_error) { InheritedProofing::Errors::AccessTokenExpiredError }

      it 'returns an access token expired error' do
        expect { subject }.to raise_error(expected_error)
      end
    end

    context 'when access token jwt is encoded with a signature that does not match public key' do
      let(:public_key) { OpenSSL::PKey::RSA.new(512).public_key }
      let(:expected_error) { InheritedProofing::Errors::AccessTokenSignatureMismatchError }

      it 'returns an access token signature mismatch error' do
        expect { subject }.to raise_error(expected_error)
      end
    end

    context 'when access token jwt is malformed' do
      let(:access_token_jwt) { 'some-messed-up-jwt' }
      let(:expected_error) { InheritedProofing::Errors::AccessTokenMalformedJWTError }

      it 'raises an access token malformed jwt error' do
        expect { subject }.to raise_error(expected_error)
      end
    end

    context 'when access token payload does not include inherited_proofing_auth' do
      let(:payload) { { exp: expiration_time.to_i } }
      let(:expected_error) { InheritedProofing::Errors::AccessTokenMissingRequiredAttributesError }

      it 'raises an access token missing required attribute error' do
        expect { subject }.to raise_error(expected_error)
      end
    end

    context 'when access token jwt is valid' do
      it 'returns a hash with inherited proofing auth code' do
        decoded_access_token = subject
        expect(decoded_access_token.inherited_proofing_auth).to eq(auth_code)
      end
    end
  end
end
