# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Chatbot::CodeContainer, type: :model do
  let(:chatbot_code_container) do
    create(:chatbot_code_container, code:, icn:)
  end

  let(:code) { 'some-code' }
  let(:icn) { 'some-icn' }

  describe 'validations' do
    describe '#code' do
      subject { chatbot_code_container.code }

      context 'when code is nil' do
        let(:code) { nil }
        let(:expected_error) { Common::Exceptions::ValidationErrors }
        let(:expected_error_message) { 'Validation error' }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end

    describe '#icn' do
      subject { chatbot_code_container.icn }

      context 'when icn is nil' do
        let(:icn) { nil }
        let(:expected_error) { Common::Exceptions::ValidationErrors }
        let(:expected_error_message) { 'Validation error' }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end
  end
end
