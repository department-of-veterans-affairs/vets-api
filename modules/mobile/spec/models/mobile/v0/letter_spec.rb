# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mobile::V0::Letter, type: :model do
  describe '#displayable?' do
    context 'for letters in VISIBLE_TYPES' do
      it 'returns true for benefit_summary' do
        letter = described_class.new(letter_type: 'benefit_summary', name: 'Benefit Summary Letter')
        expect(letter.displayable?).to eq(true)
      end

      it 'returns true for commissary' do
        letter = described_class.new(letter_type: 'commissary', name: 'Commissary Letter')
        expect(letter.displayable?).to eq(true)
      end
    end

    context 'for letters not in VISIBLE_TYPES' do
      it 'returns false for benefit_summary_dependent' do
        letter = described_class.new(letter_type: 'benefit_summary_dependent', name: 'Dependent Letter')
        expect(letter.displayable?).to eq(false)
      end

      it 'returns false for certificate_of_eligibility' do
        letter = described_class.new(letter_type: 'certificate_of_eligibility', name: 'COE Letter')
        expect(letter.displayable?).to eq(false)
      end
    end

    context 'for foreign_medical_program letter' do
      let(:letter) do
        described_class.new(letter_type: 'foreign_medical_program', name: 'Foreign Medical Program Letter')
      end

      context 'when fmp_benefits_authorization_letter flag is disabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:fmp_benefits_authorization_letter).and_return(false)
        end

        it 'returns false' do
          expect(letter.displayable?).to eq(false)
        end
      end

      context 'when fmp_benefits_authorization_letter flag is enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:fmp_benefits_authorization_letter).and_return(true)
        end

        it 'returns true' do
          expect(letter.displayable?).to eq(true)
        end
      end
    end
  end

  describe '#initialize' do
    context 'when letter_type is benefit_summary' do
      it 'sets custom name' do
        letter = described_class.new(letter_type: 'benefit_summary', name: 'Original Name')
        expect(letter.name).to eq('Benefit Summary and Service Verification Letter')
      end
    end

    context 'when letter_type is foreign_medical_program' do
      it 'sets custom name' do
        letter = described_class.new(letter_type: 'foreign_medical_program', name: 'Original Name')
        expect(letter.name).to eq('Foreign Medical Program Enrollment Letter')
      end
    end

    context 'when letter_type is other' do
      it 'keeps original name' do
        letter = described_class.new(letter_type: 'commissary', name: 'Commissary Letter')
        expect(letter.name).to eq('Commissary Letter')
      end
    end
  end
end
