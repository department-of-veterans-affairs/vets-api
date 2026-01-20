# frozen_string_literal: true

require 'rails_helper'
require 'bpds/jwt_generator'

RSpec.describe BPDS::JwtGenerator do
  describe '#encode_jwt' do
    it 'returns a token with required fields' do
      encoded_jwt = BPDS::JwtGenerator.encode_jwt
      decoded_jwt = JWT.decode(encoded_jwt, Settings.bpds.jwt_secret, true, {
                                 typ: 'JWT',
                                 alg: 'HS256'
                               }).first
      expect(decoded_jwt.keys).to include('iss', 'jti', 'expires', 'iat')
      expect(decoded_jwt['iss']).to eq('vets-api')
    end
  end
end
