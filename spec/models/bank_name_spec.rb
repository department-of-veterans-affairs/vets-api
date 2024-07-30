# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BankName, type: :model do
  let(:user) { FactoryBot.create(:ch33_dd_user) }

  before { allow_any_instance_of(User).to receive(:common_name).and_return('abraham.lincoln@vets.gov') }

  describe '.get_bank_name' do
    context 'with blank routing number' do
      it 'returns nil' do
        expect(described_class.get_bank_name(user, '')).to eq(nil)
      end
    end

    context 'with cached bank name' do
      let(:bank_name) { create(:bank_name) }

      it 'returns the cached name' do
        expect(described_class.get_bank_name(user, bank_name.routing_number)).to eq(
          bank_name.bank_name
        )
      end
    end
  end
end
