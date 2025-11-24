# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RepresentationManagement::EnqueueGeocodingJob, type: :job do
  describe '#perform' do
    let!(:veteran_rep_with_location) do
      create(:representative,
             representative_id: 'has-location',
             lat: 38.0,
             long: -77.0,
             location: 'POINT(-77.0 38.0)')
    end

    let!(:veteran_rep_without_lat) do
      create(:representative,
             representative_id: 'no-lat',
             lat: nil,
             long: -77.0,
             location: 'POINT(-77.0 38.0)')
    end

    let!(:veteran_rep_without_long) do
      create(:representative,
             representative_id: 'no-long',
             lat: 38.0,
             long: nil,
             location: 'POINT(-77.0 38.0)')
    end

    let!(:veteran_rep_without_location) do
      create(:representative,
             representative_id: 'no-location',
             lat: 38.0,
             long: -77.0,
             location: nil)
    end

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
      allow(Rails.logger).to receive(:info)
    end

    it 'enqueues geocoding jobs for veteran representatives missing geocoding data' do
      described_class.new.perform

      # Should enqueue jobs for 3 veteran reps (missing lat, long, or location)
      veteran_rep_ids = [
        veteran_rep_without_lat.representative_id,
        veteran_rep_without_long.representative_id,
        veteran_rep_without_location.representative_id
      ]

      # Verify each veteran rep got a job scheduled
      veteran_rep_ids.each do |rep_id|
        expect(RepresentationManagement::GeocodeRepresentativeJob).to have_received(:perform_in).with(
          anything,
          'Veteran::Service::Representative',
          rep_id
        ).once
      end
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
        'Veteran::Service::Representative',
        veteran_rep_with_location.representative_id
      )

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
      allow(RepresentationManagement::GeocodeRepresentativeJob).to receive(:perform_in) do |delay, *args|
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

    it 'logs the total number of jobs enqueued' do
      described_class.new.perform

      expect(Rails.logger).to have_received(:info).with('Enqueued 6 geocoding jobs')
    end

    context 'when there are no records missing geocoding data' do
      before do
        # Update all records to have complete geocoding data
        Veteran::Service::Representative.update_all(lat: 38.0, long: -77.0, location: 'POINT(-77.0 38.0)')
        AccreditedIndividual.update_all(lat: 38.0, long: -77.0, location: 'POINT(-77.0 38.0)')
      end

      it 'does not enqueue any jobs' do
        described_class.new.perform

        expect(RepresentationManagement::GeocodeRepresentativeJob).not_to have_received(:perform_in)
      end

      it 'logs that 0 jobs were enqueued' do
        described_class.new.perform

        expect(Rails.logger).to have_received(:info).with('Enqueued 0 geocoding jobs')
      end
    end

    context 'with large number of records' do
      before do
        # Create 10 more records without geocoding data
        10.times do |i|
          create(:representative,
                 representative_id: "batch-rep-#{i}",
                 lat: nil,
                 long: nil,
                 location: nil)
        end

        5.times do |i|
          create(:accredited_individual,
                 registration_number: "batch-ind-#{i}",
                 lat: nil,
                 long: nil,
                 location: nil)
        end
      end

      it 'enqueues all jobs with proper spacing' do
        described_class.new.perform

        # 3 original veteran reps + 10 new + 3 original individuals + 5 new = 21 total
        expect(RepresentationManagement::GeocodeRepresentativeJob).to have_received(:perform_in).exactly(21).times
      end

      it 'maintains offset between veteran reps and accredited individuals' do
        described_class.new.perform

        # Verify the last veteran rep job is scheduled before the first accredited individual job
        veteran_rep_calls = []
        accredited_individual_calls = []

        allow(RepresentationManagement::GeocodeRepresentativeJob).to receive(:perform_in) do |delay, model, id|
          if model == 'Veteran::Service::Representative'
            veteran_rep_calls << delay.to_i
          else
            accredited_individual_calls << delay.to_i
          end
        end

        described_class.new.perform

        # The first accredited individual should be scheduled after all veteran reps
        expect(accredited_individual_calls.min).to be > veteran_rep_calls.max
      end
    end
  end
end
