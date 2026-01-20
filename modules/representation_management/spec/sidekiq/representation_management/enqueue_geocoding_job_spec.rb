# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RepresentationManagement::EnqueueGeocodingJob, type: :job do
  describe '#perform' do
    let!(:accredited_individual_with_location) do
      create(:accredited_individual,
             registration_number: '12345-has',
             lat: 38.0,
             long: -77.0,
             location: 'POINT(-77.0 38.0)')
    end

    let!(:accredited_individual_without_lat) do
      create(:accredited_individual,
             registration_number: '12346-no-lat',
             lat: nil,
             long: -77.0,
             location: 'POINT(-77.0 38.0)')
    end

    let!(:accredited_individual_without_long) do
      create(:accredited_individual,
             registration_number: '12347-no-long',
             lat: 38.0,
             long: nil,
             location: 'POINT(-77.0 38.0)')
    end

    let!(:accredited_individual_without_location) do
      create(:accredited_individual,
             registration_number: '12348-no-loc',
             lat: 38.0,
             long: -77.0,
             location: nil)
    end

    before do
      allow(RepresentationManagement::GeocodeRepresentativeJob).to receive(:perform_in)
    end

    it 'enqueues geocoding jobs for accredited individuals missing geocoding data' do
      described_class.new.perform

      # Should enqueue jobs for 3 accredited individuals (missing lat, long, or location)
      individual_ids = [
        accredited_individual_without_lat.id,
        accredited_individual_without_long.id,
        accredited_individual_without_location.id
      ]

      # Verify each accredited individual got a job scheduled
      individual_ids.each do |individual_id|
        expect(RepresentationManagement::GeocodeRepresentativeJob).to have_received(:perform_in).with(
          anything,
          'AccreditedIndividual',
          individual_id
        ).once
      end
    end

    it 'does not enqueue jobs for records with complete geocoding data' do
      described_class.new.perform

      expect(RepresentationManagement::GeocodeRepresentativeJob).not_to have_received(:perform_in).with(
        anything,
        'AccreditedIndividual',
        accredited_individual_with_location.id
      )
    end

    it 'spaces out jobs by 2 seconds to respect rate limits' do
      described_class.new.perform

      # Verify the time spacing is correct
      calls = []
      allow(RepresentationManagement::GeocodeRepresentativeJob).to receive(:perform_in) do |delay, *_args|
        calls << delay
      end

      described_class.new.perform

      # Extract unique delays and sort them
      delays = calls.map(&:to_i).uniq.sort

      # Verify spacing is in 2-second increments
      delays.each_with_index do |delay, index|
        expect(delay).to eq(index * 2)
      end
    end

    context 'when there are no records missing geocoding data' do
      before do
        AccreditedIndividual.find_each do |individual|
          individual.update(lat: 38.0, long: -77.0, location: 'POINT(-77.0 38.0)')
        end
      end

      it 'does not enqueue any jobs' do
        described_class.new.perform

        expect(RepresentationManagement::GeocodeRepresentativeJob).not_to have_received(:perform_in)
      end
    end

    context 'with large number of records' do
      before do
        # Create 10 more records without geocoding data
        10.times do |i|
          create(:accredited_individual,
                 registration_number: "batch-ind-#{i}",
                 lat: nil,
                 long: nil,
                 location: nil)
        end
      end

      it 'enqueues all jobs with proper spacing' do
        described_class.new.perform

        # 3 original individuals + 10 new = 13 total
        expect(RepresentationManagement::GeocodeRepresentativeJob).to have_received(:perform_in).exactly(13).times
      end
    end
  end
end
