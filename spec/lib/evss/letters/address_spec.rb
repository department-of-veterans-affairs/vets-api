# frozen_string_literal: true
require 'rails_helper'

RSpec.describe EVSS::Letters::Address, type: :model do
  describe '#initialize' do
    context 'with valid args' do
      let(:address) { build(:letter_address) }
      it 'builds a letter' do
        expect(address.address_line1).to eq('742 Evergreen Terrace')
        expect(address.address_line2).to be_nil
      end
    end
  end
end
