# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RepresentationManagement::EnqueueStaleGeocodingJob, type: :job do
  describe '#perform' do
    let(:stale_date) { 15.days.ago }
    let(:recent_date) { 10.days.ago }

    # Veteran::Service::Representative test records
    let!(:representative_stale) do
      create(:representative,
             representative_id: 'rep-stale',
             fallback_location_updated_at: stale_date,
             lat: 38.0,
             long: -77.0,
             location: 'POINT(-77.0 38.0)')
    end

    let!(:representative_recent) do
      create(:representative,
             representative_id: 'rep-recent',
             fallback_location_updated_at: recent_date,
             lat: 38.0,
             long: -77.0,
             location: 'POINT(-77.0 38.0)')
    end

    let!(:representative_null) do
      create(:representative,
             representative_id: 'rep-null',
             fallback_location_updated_at: nil,
             lat: 38.0,
             long: -77.0,
             location: 'POINT(-77.0 38.0)')
    end

    # AccreditedIndividual test records
    let!(:accredited_individual_stale) do
      create(:accredited_individual,
             registration_number: '12345-stale',
             fallback_location_updated_at: stale_date,
             lat: 38.0,
             long: -77.0,
             location: 'POINT(-77.0 38.0)')
    end

    let!(:accredited_individual_recent) do
      create(:accredited_individual,
             registration_number: '12346-recent',
             fallback_location_updated_at: recent_date,
             lat: 38.0,
             long: -77.0,
             location: 'POINT(-77.0 38.0)')
    end

    let!(:accredited_individual_null) do
      create(:accredited_individual,
             registration_number: '12347-null',
             fallback_location_updated_at: nil,
             lat: 38.0,
             long: -77.0,
             location: 'POINT(-77.0 38.0)')
    end

    before do
      allow(RepresentationManagement::GeocodeRepresentativeJob).to receive(:perform_in)
    end

    it 'enqueues geocoding jobs for Veteran::Service::Representatives with stale fallback_location_updated_at' do
      described_class.new.perform

      expect(RepresentationManagement::GeocodeRepresentativeJob).to have_received(:perform_in).with(
        anything,
        'Veteran::Service::Representative',
        representative_stale.representative_id
      ).once
    end

    it 'does not enqueue jobs for Veteran::Service::Representatives with recent fallback_location_updated_at' do
      described_class.new.perform

      expect(RepresentationManagement::GeocodeRepresentativeJob).not_to have_received(:perform_in).with(
        anything,
        'Veteran::Service::Representative',
        representative_recent.representative_id
      )
    end

    it 'does not enqueue jobs for Veteran::Service::Representatives with null fallback_location_updated_at' do
      described_class.new.perform

      expect(RepresentationManagement::GeocodeRepresentativeJob).not_to have_received(:perform_in).with(
        anything,
        'Veteran::Service::Representative',
        representative_null.representative_id
      )
    end

    it 'enqueues geocoding jobs for accredited individuals with stale fallback_location_updated_at' do
      described_class.new.perform

      expect(RepresentationManagement::GeocodeRepresentativeJob).to have_received(:perform_in).with(
        anything,
        'AccreditedIndividual',
        accredited_individual_stale.id
      ).once
    end

    it 'does not enqueue jobs for records with recent fallback_location_updated_at' do
      described_class.new.perform

      expect(RepresentationManagement::GeocodeRepresentativeJob).not_to have_received(:perform_in).with(
        anything,
        'AccreditedIndividual',
        accredited_individual_recent.id
      )
    end

    it 'does not enqueue jobs for records with null fallback_location_updated_at' do
      described_class.new.perform

      expect(RepresentationManagement::GeocodeRepresentativeJob).not_to have_received(:perform_in).with(
        anything,
        'AccreditedIndividual',
        accredited_individual_null.id
      )
    end

    it 'spaces out jobs by 2 seconds to respect rate limits' do
      # Verify the time spacing is correct
      calls = []
      allow(RepresentationManagement::GeocodeRepresentativeJob).to receive(:perform_in) do |delay, *_args|
        calls << delay
      end

      described_class.new.perform

      # Extract delays and verify spacing
      delays = calls.map(&:to_i).sort

      # Verify spacing is in 2-second increments
      # Should have 2 total jobs (1 Veteran::Service::Representative + 1 AccreditedIndividual)
      expect(delays.length).to eq(2)
      delays.each_with_index do |delay, index|
        expect(delay).to eq(index * 2)
      end
    end

    context 'when there are no stale records' do
      before do
        # Update all records to have recent timestamps
        Veteran::Service::Representative.find_each do |rep|
          rep.update(fallback_location_updated_at: recent_date)
        end
        AccreditedIndividual.find_each do |individual|
          individual.update(fallback_location_updated_at: recent_date)
        end
      end

      it 'does not enqueue any jobs' do
        described_class.new.perform

        expect(RepresentationManagement::GeocodeRepresentativeJob).not_to have_received(:perform_in)
      end
    end

    context 'with large number of stale records' do
      before do
        # Create 5 more stale Veteran::Service::Representatives
        5.times do |i|
          create(:representative,
                 representative_id: "batch-stale-rep-#{i}",
                 fallback_location_updated_at: stale_date,
                 lat: 38.0,
                 long: -77.0,
                 location: 'POINT(-77.0 38.0)')
        end
        # Create 10 more stale accredited individuals
        10.times do |i|
          create(:accredited_individual,
                 registration_number: "batch-stale-ind-#{i}",
                 fallback_location_updated_at: stale_date,
                 lat: 38.0,
                 long: -77.0,
                 location: 'POINT(-77.0 38.0)')
        end
      end

      it 'enqueues all stale jobs with proper spacing' do
        described_class.new.perform

        # 1 stale representative + 5 new representatives + 1 stale individual + 10 new individuals = 17 total
        expect(RepresentationManagement::GeocodeRepresentativeJob).to have_received(:perform_in).exactly(17).times
      end
    end
  end

  context 'with custom stale threshold' do
    it 'uses the STALE_THRESHOLD_DAYS constant' do
      expect(described_class::STALE_THRESHOLD_DAYS).to eq(14)
    end
  end
end
