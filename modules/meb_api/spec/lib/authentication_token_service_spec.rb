# frozen_string_literal: true

require 'rails_helper'
require 'authentication_token_service'

RSpec.describe MebApi::AuthenticationTokenService do
  describe '.call' do
    include ActiveSupport::Testing::TimeHelpers

    it 'generates a JWT with correct claims' do
      travel_to Time.zone.local(2024, 1, 15, 10, 0, 0) do
        token = described_class.call

        decoded_token = JWT.decode(
          token,
          described_class::RSA_PUBLIC,
          true,
          algorithm: described_class::ALGORITHM_TYPE,
          kid: described_class::KID,
          typ: described_class::TYP
        )

        payload, header = decoded_token

        expect(payload['iat']).to eq(Time.now.to_i)
        expect(payload['exp']).to eq(Time.now.to_i + (5 * 60))

        expect(header).to include(
          'kid' => 'vanotify',
          'typ' => 'JWT',
          'alg' => 'RS256'
        )
      end
    end
  end
end
