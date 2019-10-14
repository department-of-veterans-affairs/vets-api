# frozen_string_literal: true

require 'rails_helper'

describe VAOS::JWT do
  subject { VAOS::JWT.new(user) }
  let(:user) { build(:user, :mhv) }

  describe '#token' do
    it 'encodes a payload' do
      rsa_private = OpenSSL::PKey::RSA.generate 4096
      allow(File).to receive(:read).and_return(rsa_private)
      decoded = JWT.decode(subject.token, rsa_private.public_key, true, algorithm: 'RS512').first
      expect(decoded['firstName']).to eq(user.first_name)
    end
  end
end
