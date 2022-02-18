# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BankName, type: :model do
  let(:user) { FactoryBot.create(:ch33_dd_user) }

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

    context 'with cache miss' do
      def get_bank_name
        described_class.get_bank_name(user, '122400724')
      end

      it 'returns the bank name and saves it in cache' do
        VCR.use_cassette('bgs/ddeft/find_bank_name_valid', VCR::MATCH_EVERYTHING) do
          expect(get_bank_name).to eq('BANK OF AMERICA, N.A.')
        end

        expect(get_bank_name).to eq('BANK OF AMERICA, N.A.')
      end
    end
  end
end
