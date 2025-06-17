# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SignIn::StateCode, type: :model do
  describe 'validations' do
    context 'when code is nil' do
      subject(:state_code) { described_class.new(code: nil) }

      it 'is invalid' do
        expect(state_code).not_to be_valid
        expect(state_code.errors[:code]).to include("can't be blank")
      end

      it 'raises ActiveModel::ValidationError on save!' do
        expect { state_code.save! }.to raise_error(ActiveModel::ValidationError)
      end
    end
  end
end