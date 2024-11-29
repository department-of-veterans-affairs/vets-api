# frozen_string_literal: true

require 'rails_helper'
require 'post911_sob/dgib/authentication_token_service'

Rspec.describe Post911SOB::DGIB::AuthenticationTokenService do
  describe '.call' do
    let(:token) { described_class.call }

    it 'returns an authentication token' do
      decoded_token = JWT.decode(token,
                                 described_class::RSA_PUBLIC,
                                 true,
                                 { algorithm: described_class::ALGORITHM_TYPE,
                                   kid: described_class::KID,
                                   typ: described_class::TYP })
      expect(decoded_token).to eq(
        [{
          'nbf' => Time.now.to_i,
          'exp' => Time.now.to_i + (5 * 60),
          'realm_access' => { 'roles' => ['SOB'] }
        }, {
          'kid' => 'sob',
          'typ' => 'JWT',
          'alg' => 'RS256'
        }]
      )
    end
  end
end
