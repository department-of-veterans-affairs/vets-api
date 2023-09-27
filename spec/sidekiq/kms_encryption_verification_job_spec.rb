# frozen_string_literal: true

require 'rails_helper'

RSpec.describe KmsEncryptionVerificationJob do
  describe '#perform' do
    before do
      @h1 = HCAAttachment.create(file_data: 'testing 1')
      @h2 = HCAAttachment.create(file_data: 'testing 2')
    end

    let(:subject) { described_class.new }

    it 'raises an error when decryption fails' do
      allow_any_instance_of(described_class).to receive(:can_decrypt?).and_return(false)

      expect do
        subject.perform(['HCAAttachment'])
      end.to raise_error(Lockbox::DecryptionError)
    end

    it 'does not raise an error when decryption succeeds' do
      expect do
        subject.perform(['HCAAttachment'])
      end.not_to raise_error
    end
  end
end
