# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::StateCode, type: :model do
  let(:state_code) { create(:state_code, code:) }
  let(:code) { SecureRandom.hex }

  describe 'validations' do
    describe '#code' do
      subject { state_code.code }

      context 'when code is nil' do
        let(:code) { nil }
        let(:expected_error) { Common::Exceptions::ValidationErrors }
        let(:expected_error_message) { 'Validation error' }

        it 'raises validation error' do
          expect { subject }.to raise_error(expected_error, expected_error_message)
        end
      end
    end
  end
end
