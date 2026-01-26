# frozen_string_literal: true

require 'rails_helper'
require 'vye/dgib/authentication_token_service'

RSpec.describe Vye::DGIB::AuthenticationTokenService do
  describe '.call' do
    let(:token) { described_class.call }

    it 'returns an authentication token' do
      decoded_token =
        JWT.decode(
          token,
          described_class::RSA_PRIVATE,
          true,
          {
            algorithm: described_class::ALGORITHM_TYPE,
            kid: Settings.dgi.vye.jwt.kid,
            typ: described_class::TYP
          }
        )

      expect(decoded_token).to eq(
        [{
          'nbf' => Time.now.to_i,
          'exp' => Time.now.to_i + (5 * 60),
          'realm_access' => { 'roles' => ['VYE'] }
        }, {
          'kid' => 'vye',
          'typ' => 'JWT',
          'alg' => 'RS256'
        }]
      )
    end
  end
end
