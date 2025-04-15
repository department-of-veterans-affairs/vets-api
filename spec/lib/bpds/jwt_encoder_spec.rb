# frozen_string_literal: true

require 'rails_helper'
require 'bpds/jwt_encoder'

RSpec.describe Bpds::JwtEncoder do
  describe '#get_token' do
    it 'returns a token with required fields' do
      encoded_jwt = Bpds::JwtEncoder.new.get_token
      decoded_jwt = JWT.decode(encoded_jwt, Settings.bpds.jwt_secret, true, {
                                 typ: 'JWT',
                                 alg: 'HS256'
                               }).first
      expect(decoded_jwt.keys).to include('iss', 'jti', 'expires', 'iat')
      expect(decoded_jwt['iss']).to eq('vets-api')
    end
  end
end
