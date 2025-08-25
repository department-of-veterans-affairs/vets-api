# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::IcnTemporaryIdentifier, type: :model do
  describe '.save_icn' do
    let(:icn) { '123498767V234859' }

    context 'when a record with the ICN does not exist' do
      it 'creates a new record with the ICN and returns it' do
        expect do
          record = described_class.save_icn(icn)
          expect(record).to be_persisted
          expect(record.icn).to eq(icn)
        end.to change(described_class, :count).by(1)

        expect(described_class.where(icn:)).to exist
      end
    end

    context 'when a record with the ICN already exists' do
      it 'does not create a duplicate and returns the existing record' do
        existing = described_class.create!(icn:)

        expect do
          returned = described_class.save_icn(icn)
          expect(returned.id).to eq(existing.id)
          expect(returned.icn).to eq(icn)
        end.not_to change(described_class, :count)
      end
    end
  end

  describe '.lookup_icn' do
    let(:uuid) { SecureRandom.uuid }

    it 'returns the icn from the found record' do
      fake_record = instance_double(described_class.name, icn: '789456123V987654')
      expect(described_class).to receive(:find).with(uuid).and_return(fake_record)

      expect(described_class.lookup_icn(uuid)).to eq('789456123V987654')
    end

    it 'raises ActiveRecord::RecordNotFound when the record is missing' do
      expect(described_class).to receive(:find).with(uuid)
                                               .and_raise(ActiveRecord::RecordNotFound)

      expect { described_class.lookup_icn(uuid) }
        .to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
