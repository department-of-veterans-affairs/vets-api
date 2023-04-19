# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mobile::V0::LighthouseAssertion, type: :model do
  describe '.jwt' do
    let(:uuid) { '84c939ec-b7c5-4f51-94a0-d6755b682216' }
    let(:rsa_key) { OpenSSL::PKey::RSA.generate(2048) }

    before do
      Timecop.freeze(Time.utc(2021, 10, 11, 0, 0, 0))
      allow(SecureRandom).to receive(:uuid).and_return(uuid)
      allow(File).to receive(:read).and_return(rsa_key.to_s)
    end

    after { Timecop.return }

    it 'encodes the health claim as a jwt token' do
      expect(JWT.decode(Mobile::V0::LighthouseAssertion.new(:health).token, rsa_key.public_key, true,
                        { algorithm: 'RS512' })).to eq(
                          [
                            {
                              'aud' => 'https://deptva-eval.okta.com/oauth2/aus8nm1q0f7VQ0a482p7/v1/token',
                              'iss' => '0oad0xggirKLf2ger2p7',
                              'sub' => '0oad0xggirKLf2ger2p7',
                              'jti' => uuid,
                              'iat' => 1_633_910_400,
                              'exp' => 1_633_910_700
                            },
                            {
                              'alg' => 'RS512'
                            }
                          ]
                        )
    end
  end
end
