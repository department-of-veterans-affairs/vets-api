# frozen_string_literal: true

require 'rails_helper'
require 'inherited_proofing/user_attributes_encryptor'

RSpec.describe InheritedProofing::UserAttributesEncryptor do
  describe '#perform' do
    subject do
      InheritedProofing::UserAttributesEncryptor.new(user_attributes:).perform
    end

    let(:user_attributes) { { user_attributes: 'some-user-attributes' } }
    let(:private_key) { OpenSSL::PKey::RSA.new(512) }
    let(:public_key) { private_key.public_key }

    before do
      allow_any_instance_of(InheritedProofing::UserAttributesEncryptor).to receive(:public_key).and_return(public_key)
    end

    it 'encrypts the given user_attributes' do
      encrypted_attributes = subject
      expect(JWE.decrypt(encrypted_attributes, private_key)).to eq(user_attributes.to_json)
    end
  end
end
