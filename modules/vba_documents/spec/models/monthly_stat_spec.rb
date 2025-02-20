# frozen_string_literal: true

require 'rails_helper'

describe VBADocuments::MonthlyStat, type: :model do
  describe 'validations' do
    context 'when constructed with a valid month and year' do
      let(:monthly_stat) { build(:monthly_stat, month: 12, year: 2023) }

      it 'is a valid record' do
        expect(monthly_stat).to be_valid
      end
    end

    context 'when constructed with an invalid month' do
      let(:monthly_stat) { build(:monthly_stat, month: 'December', year: 2023) }

      it 'is not a valid record' do
        expect(monthly_stat).not_to be_valid
      end
    end

    context 'when constructed with an invalid year' do
      let(:monthly_stat) { build(:monthly_stat, month: 12, year: 23) }

      it 'is not a valid record' do
        expect(monthly_stat).not_to be_valid
      end
    end

    context 'when a report already exists for the month and year' do
      let(:monthly_stat) { build(:monthly_stat, month: 1, year: 2023) }

      before { create(:monthly_stat, month: 1, year: 2023) }

      it 'is not a valid record' do
        expect(monthly_stat).not_to be_valid
      end
    end
  end
end
