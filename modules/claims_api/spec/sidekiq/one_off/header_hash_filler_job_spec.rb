# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/filler'

RSpec.describe ClaimsApi::OneOff::HeaderHashFillerJob, type: :job do
  subject { described_class.new }

  before do
    Timecop.freeze(1.year.ago) do
      create_list(:power_of_attorney, 10)
      ClaimsApi::PowerOfAttorney.update_all(header_hash: nil) # rubocop:disable Rails/SkipsModelValidations
    end
  end

  describe '#perform' do
    it 'fills header_hash for POA records where it is missing' do
      ClaimsApi::PowerOfAttorney.first.save # Fills in header hash, so we can test filling for others
      expect do
        subject.perform 'ClaimsApi::PowerOfAttorney'
      end.to change { ClaimsApi::PowerOfAttorney.where(header_hash: nil).count }.from(9).to(0)
    end

    it 'fills in header_hash for specific records' do
      ids =  ClaimsApi::PowerOfAttorney.all.pluck(:id).sample(3)
      subject.perform 'ClaimsApi::PowerOfAttorney', ids
      ids.each do |id|
        expect(ClaimsApi::PowerOfAttorney.find_by(id:).header_hash).not_to be_blank
      end
      # Ensure other records are not affected
      expect(ClaimsApi::PowerOfAttorney.where.not(id: ids).first.header_hash).to be_blank
    end

    it 'does not change timestamps when filling header_hash' do
      poa = ClaimsApi::PowerOfAttorney.first
      original_updated_at = poa.updated_at
      subject.perform 'ClaimsApi::PowerOfAttorney', [poa.id]
      expect(poa.reload.updated_at).to eq(original_updated_at)
    end

    it 'logs count of records processed' do
      expect(ClaimsApi::Logger).to receive(:log).with(
        'header_hash_filler_job',
        details: 'ClaimsApi::PowerOfAttorney completed with 10 record(s)'
      )

      subject.perform 'ClaimsApi::PowerOfAttorney'
    end

    it 'logs an error and returns cleanly if filling header_hash fails' do
      allow_any_instance_of(ClaimsApi::PowerOfAttorney)
        .to receive(:set_header_hash).and_raise(StandardError.new('Test error'))
      poa = ClaimsApi::PowerOfAttorney.first

      expect(ClaimsApi::Logger).to receive(:log).twice # Once for the error, once for the completion log

      expect do
        subject.perform('ClaimsApi::PowerOfAttorney', [poa.id])
      end.not_to raise_error
    end

    it 'works on AutoEstablishedClaims too' do
      create_list(:auto_established_claim, 10)
      ClaimsApi::AutoEstablishedClaim.update_all(header_hash: nil) # rubocop:disable Rails/SkipsModelValidations
      ClaimsApi::AutoEstablishedClaim.first.save # Fills in header hash, so we can test filling for others
      expect do
        subject.perform 'ClaimsApi::AutoEstablishedClaim'
      end.to change { ClaimsApi::AutoEstablishedClaim.where(header_hash: nil).count }.from(9).to(0)
    end
  end
end
