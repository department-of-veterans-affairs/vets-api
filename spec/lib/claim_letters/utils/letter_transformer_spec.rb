# frozen_string_literal: true

require 'rails_helper'
require 'claim_letters/utils/letter_transformer'

RSpec.describe ClaimLetters::Utils::LetterTransformer do
  describe '.allowed?' do
    let(:allowed_doctypes) { %w[27 123 456] }

    context 'when doc has :doc_type key' do
      it 'returns true when doc_type is in allowed list' do
        doc = { doc_type: '27' }
        expect(described_class.allowed?(doc, allowed_doctypes)).to be true
      end

      it 'returns false when doc_type is not in allowed list' do
        doc = { doc_type: '999' }
        expect(described_class.allowed?(doc, allowed_doctypes)).to be false
      end

      it 'handles nil doc_type' do
        doc = { doc_type: nil }
        expect(described_class.allowed?(doc, allowed_doctypes)).to be false
      end
    end

    context 'when doc has docTypeId key (string)' do
      it 'returns true when docTypeId is in allowed list' do
        doc = { 'docTypeId' => '27' }
        expect(described_class.allowed?(doc, allowed_doctypes)).to be true
      end

      it 'returns false when docTypeId is not in allowed list' do
        doc = { 'docTypeId' => '999' }
        expect(described_class.allowed?(doc, allowed_doctypes)).to be false
      end
    end

    context 'when doc has docTypeId key (integer)' do
      it 'converts integer to string and checks allowed list' do
        doc = { 'docTypeId' => 27 }
        expect(described_class.allowed?(doc, allowed_doctypes)).to be true
      end

      it 'returns false for integer not in allowed list' do
        doc = { 'docTypeId' => 999 }
        expect(described_class.allowed?(doc, allowed_doctypes)).to be false
      end
    end

    context 'when doc has both :doc_type and docTypeId' do
      it 'prefers :doc_type over docTypeId' do
        doc = { doc_type: '27', 'docTypeId' => '999' }
        expect(described_class.allowed?(doc, allowed_doctypes)).to be true
      end
    end

    context 'edge cases' do
      it 'handles empty allowed_doctypes array' do
        doc = { doc_type: '27' }
        expect(described_class.allowed?(doc, [])).to be false
      end

      it 'handles doc without doc_type or docTypeId keys' do
        doc = { some_other_key: '27' }
        expect(described_class.allowed?(doc, allowed_doctypes)).to be false
      end
    end
  end

  describe '.filter_boa' do
    context 'when received_at is nil' do
      it 'returns true (does not filter) for BOA documents' do
        doc = { doc_type: '27', received_at: nil }
        expect(described_class.filter_boa(doc)).to be true
      end

      it 'returns true (does not filter) for non-BOA documents' do
        doc = { doc_type: '123', received_at: nil }
        expect(described_class.filter_boa(doc)).to be true
      end
    end

    context 'when received_at is present' do
      context 'for BOA documents (doc_type 27)' do
        it 'returns false (filters) when received less than 2 days ago' do
          doc = {
            doc_type: '27',
            received_at: 1.day.ago
          }
          expect(described_class.filter_boa(doc)).to be false
        end

        it 'returns false (filters) when received today' do
          doc = {
            doc_type: '27',
            received_at: Time.zone.now
          }
          expect(described_class.filter_boa(doc)).to be false
        end

        it 'returns true (does not filter) when received exactly 2 days ago' do
          doc = {
            doc_type: '27',
            received_at: 2.days.ago
          }
          expect(described_class.filter_boa(doc)).to be true
        end

        it 'returns true (does not filter) when received more than 2 days ago' do
          doc = {
            doc_type: '27',
            received_at: 5.days.ago
          }
          expect(described_class.filter_boa(doc)).to be true
        end
      end

      context 'for non-BOA documents' do
        it 'returns true regardless of received_at date' do
          doc = {
            doc_type: '123',
            received_at: 1.hour.ago
          }
          expect(described_class.filter_boa(doc)).to be true
        end
      end
    end

    context 'edge cases' do
      it 'handles DateTime objects' do
        doc = {
          doc_type: '27',
          received_at: DateTime.now - 1
        }
        expect(described_class.filter_boa(doc)).to be false
      end

      it 'handles Time objects' do
        doc = {
          doc_type: '27',
          received_at: 1.day.ago
        }
        expect(described_class.filter_boa(doc)).to be false
      end
    end
  end

  describe '.decorate_description' do
    before do
      # Mock the DOCTYPE_TO_TYPE_DESCRIPTION constant
      stub_const('ClaimLetters::Responses::DOCTYPE_TO_TYPE_DESCRIPTION', {
                   '27' => 'Board of Appeals Decision Letter',
                   '123' => 'Claim Development Letter',
                   '456' => 'Award Letter'
                 })
    end

    it 'returns the correct description for a known doc_type' do
      expect(described_class.decorate_description('27')).to eq('Board of Appeals Decision Letter')
      expect(described_class.decorate_description('123')).to eq('Claim Development Letter')
      expect(described_class.decorate_description('456')).to eq('Award Letter')
    end

    it 'returns nil for an unknown doc_type' do
      expect(described_class.decorate_description('999')).to be_nil
    end

    it 'handles nil doc_type' do
      expect(described_class.decorate_description(nil)).to be_nil
    end

    it 'handles integer doc_type as string key' do
      expect(described_class.decorate_description(27)).to be_nil
    end
  end

  describe '.filename_with_date' do
    it 'generates correct filename with Date object' do
      date = Date.new(2024, 3, 15)
      expect(described_class.filename_with_date(date)).to eq('ClaimLetter-2024-3-15.pdf')
    end

    it 'generates correct filename with Time object' do
      time = Time.zone.local(2024, 12, 25, 10, 30, 0)
      expect(described_class.filename_with_date(time)).to eq('ClaimLetter-2024-12-25.pdf')
    end

    it 'generates correct filename with DateTime object' do
      datetime = DateTime.new(2024, 1, 1, 8, 0, 0)
      expect(described_class.filename_with_date(datetime)).to eq('ClaimLetter-2024-1-1.pdf')
    end

    it 'generates correct filename for single-digit months and days' do
      date = Date.new(2024, 1, 5)
      expect(described_class.filename_with_date(date)).to eq('ClaimLetter-2024-1-5.pdf')
    end

    it 'generates correct filename for double-digit months and days' do
      date = Date.new(2024, 11, 30)
      expect(described_class.filename_with_date(date)).to eq('ClaimLetter-2024-11-30.pdf')
    end

    context 'edge cases' do
      it 'handles leap year date' do
        date = Date.new(2024, 2, 29)
        expect(described_class.filename_with_date(date)).to eq('ClaimLetter-2024-2-29.pdf')
      end

      it 'raises error for nil date' do
        expect { described_class.filename_with_date(nil) }.to raise_error(NoMethodError)
      end
    end
  end

  describe 'FILENAME constant' do
    it 'has the expected value' do
      expect(described_class::FILENAME).to eq('ClaimLetter')
    end
  end
end
