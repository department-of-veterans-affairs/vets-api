# frozen_string_literal: true

require 'rails_helper'

Rspec.describe MebApi::AuthenticationTokenService do
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
          'iat' => Time.now.to_i,
          'exp' => Time.now.to_i + (5 * 60)
        }, {
          'kid' => 'vanotify',
          'typ' => 'JWT',
          'alg' => 'RS256'
        }]
      )
    end
  end
end
