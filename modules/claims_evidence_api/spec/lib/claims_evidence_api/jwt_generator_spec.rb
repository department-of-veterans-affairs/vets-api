# frozen_string_literal: true

require 'rails_helper'
require 'claims_evidence_api/jwt_generator'

RSpec.describe ClaimsEvidenceApi::JwtGenerator do
  describe '#get_token' do
    it 'returns a token with required fields' do
      encoded_jwt = ClaimsEvidenceApi::JwtGenerator.new.encode_jwt
      decoded_jwt = JWT.decode(encoded_jwt, Settings.claims_evidence_api.jwt_secret,
                               true, { typ: 'JWT', alg: 'HS256' }).first
      expect(decoded_jwt.keys).to include('iss', 'jti', 'exp', 'iat', 'applicationID', 'userID', 'stationID')
      expect(decoded_jwt['iss']).to eq('VAGOV')
      expect(decoded_jwt['applicationID']).to eq('VAGOV')
      expect(decoded_jwt['userID']).to eq('VAGOVSYSACCT')
      expect(decoded_jwt['stationID']).to eq('283')
    end
  end
end
