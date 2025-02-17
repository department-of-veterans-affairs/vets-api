# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::StatePayloadVerifier do
  describe '#perform' do
    subject do
      SignIn::StatePayloadVerifier.new(state_payload:).perform
    end

    let(:state_payload) { create(:state_payload, code:) }
    let(:code) { 'some-code' }

    context 'when code in state payload is not valid' do
      let(:expected_error) { SignIn::Errors::StateCodeInvalidError }
      let(:expected_error_message) { 'Code in state is not valid' }

      it 'raises a code is not valid error' do
        expect { subject }.to raise_error(expected_error, expected_error_message)
      end
    end

    context 'when code in state payload is valid' do
      before { SignIn::StateCode.new(code:).save! }

      it 'returns nil' do
        expect(subject).to be_nil
      end

      it 'deletes the existing state code' do
        expect { subject }.to change { SignIn::StateCode.find(code) }.to(nil)
      end
    end
  end
end
