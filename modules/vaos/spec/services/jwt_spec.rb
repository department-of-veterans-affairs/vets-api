# frozen_string_literal: true

require 'rails_helper'

describe VAOS::JWT do
  let(:user) { build(:user, :mhv) }
  subject { VAOS::JWT.new(user) }

  describe '.new' do
    it 'creates a VAOS::JWT instance' do
      expect(subject).to be_an_instance_of(VAOS::JWT)
    end
  end

  describe '#token' do
    let(:expected) do
      [{ 'exp' => Time.now.utc.to_i + 4 * 3600,
         'firstName' => user.first_name,
         'idType' => 'ICN',
         'iss' => 'gov.va.api',
         'jti' => Digest::MD5.hexdigest(Time.now.utc.to_s),
         'lastName' => user.last_name,
         'nbf' => Time.now.utc.to_i - 3600,
         'sub' => '1000123456V123456' },
       { 'alg' => 'RS512' }]
    end

    it 'encodes a payload' do
      rsa_private = OpenSSL::PKey::RSA.generate 4096
      allow(File).to receive(:read).and_return(rsa_private)
      expect(JWT.decode(subject.token, rsa_private.public_key, true, algorithm: 'RS512')).to eq(expected)
    end
  end
end

