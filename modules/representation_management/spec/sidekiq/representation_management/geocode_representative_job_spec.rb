# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RepresentationManagement::GeocodeRepresentativeJob, type: :job do
  describe '#perform' do
    let(:geocoding_result) do
      double('Geocoder::Result',
             latitude: 38.8977,
             longitude: -77.0365)
    end

    before do
      allow(Geocoder).to receive(:search).and_return([geocoding_result])
      allow(Rails.logger).to receive(:info)
      allow(Rails.logger).to receive(:error)
    end

    context 'with Veteran::Service::Representative' do
      let!(:representative) do
        create(:representative,
               representative_id: 'test-rep-123',
               address_line1: '1600 Pennsylvania Ave NW',
               city: 'Washington',
               state_code: 'DC',
               zip_code: '20500',
               lat: nil,
               long: nil,
               location: nil)
      end

      it 'geocodes the representative successfully' do
        described_class.new.perform('Veteran::Service::Representative', representative.representative_id)

        representative.reload
        expect(representative.lat).to eq(38.8977)
        expect(representative.long).to eq(-77.0365)
        expect(representative.location.to_s).to eq('POINT (-77.0365 38.8977)')
      end

      it 'logs success message' do
        described_class.new.perform('Veteran::Service::Representative', representative.representative_id)

        expect(Rails.logger).to have_received(:info).with(
          "Successfully geocoded Veteran::Service::Representative##{representative.representative_id}"
        )
      end

      context 'when representative has no geocodable address' do
        let!(:representative_no_address) do
          create(:representative,
                 representative_id: 'no-address-rep',
                 address_line1: nil,
                 city: nil,
                 state_code: nil,
                 zip_code: nil)
        end

        it 'logs that no geocodable address was found' do
          described_class.new.perform('Veteran::Service::Representative', representative_no_address.representative_id)

          expect(Rails.logger).to have_received(:info).with(
            "No geocodable address for Veteran::Service::Representative##{representative_no_address.representative_id}"
          )
        end

        it 'does not call Geocoder' do
          described_class.new.perform('Veteran::Service::Representative', representative_no_address.representative_id)

          expect(Geocoder).not_to have_received(:search)
        end
      end

      context 'when representative does not exist' do
        it 'logs an error and does not retry' do
          expect do
            described_class.new.perform('Veteran::Service::Representative', 'nonexistent-id')
          end.not_to raise_error

          expect(Rails.logger).to have_received(:error).with(
            /Record not found for Veteran::Service::Representative#nonexistent-id/
          )
        end
      end
    end

    context 'with AccreditedIndividual' do
      let!(:individual) do
        create(:accredited_individual,
               address_line1: '1600 Pennsylvania Ave NW',
               city: 'Washington',
               state_code: 'DC',
               zip_code: '20500',
               lat: nil,
               long: nil,
               location: nil)
      end

      it 'geocodes the individual successfully' do
        described_class.new.perform('AccreditedIndividual', individual.id)

        individual.reload
        expect(individual.lat).to eq(38.8977)
        expect(individual.long).to eq(-77.0365)
        expect(individual.location.to_s).to eq('POINT (-77.0365 38.8977)')
      end

      it 'logs success message' do
        described_class.new.perform('AccreditedIndividual', individual.id)

        expect(Rails.logger).to have_received(:info).with(
          "Successfully geocoded AccreditedIndividual##{individual.id}"
        )
      end

      context 'when individual has no geocodable address' do
        let!(:individual_no_address) do
          create(:accredited_individual,
                 address_line1: nil,
                 city: nil,
                 state_code: nil,
                 zip_code: nil)
        end

        it 'logs that no geocodable address was found' do
          described_class.new.perform('AccreditedIndividual', individual_no_address.id)

          expect(Rails.logger).to have_received(:info).with(
            "No geocodable address for AccreditedIndividual##{individual_no_address.id}"
          )
        end

        it 'does not call Geocoder' do
          described_class.new.perform('AccreditedIndividual', individual_no_address.id)

          expect(Geocoder).not_to have_received(:search)
        end
      end

      context 'when individual does not exist' do
        it 'logs an error and does not retry' do
          fake_uuid = SecureRandom.uuid

          expect do
            described_class.new.perform('AccreditedIndividual', fake_uuid)
          end.not_to raise_error

          expect(Rails.logger).to have_received(:error).with(
            /Record not found for AccreditedIndividual##{fake_uuid}/
          )
        end
      end
    end

    context 'when geocoding fails with an error' do
      let!(:representative) do
        create(:representative,
               representative_id: 'error-rep',
               address_line1: '123 Main St',
               city: 'Anytown',
               state_code: 'ST',
               zip_code: '12345')
      end

      before do
        allow_any_instance_of(Veteran::Service::Representative)
          .to receive(:geocode_and_update_location!)
          .and_raise(StandardError.new('Database error'))
      end

      it 'logs the error and re-raises for Sidekiq retry' do
        expect do
          described_class.new.perform('Veteran::Service::Representative', representative.representative_id)
        end.to raise_error(StandardError, 'Database error')

        expect(Rails.logger).to have_received(:error).with(
          /Geocode job failed for Veteran::Service::Representative##{representative.representative_id}/
        )
      end
    end

    context 'with invalid model class name' do
      let!(:representative) do
        create(:representative, representative_id: 'test-rep')
      end

      it 'raises an error' do
        expect do
          described_class.new.perform('InvalidModel', representative.representative_id)
        end.to raise_error(NameError)
      end
    end

    context 'when geocoding returns no results' do
      let!(:representative) do
        create(:representative,
               representative_id: 'no-results-rep',
               address_line1: 'Invalid Address XYZ123',
               city: 'Nowhere',
               state_code: 'ZZ',
               zip_code: '00000')
      end

      before do
        allow(Geocoder).to receive(:search).and_return([])
      end

      it 'logs that no geocodable address was found' do
        described_class.new.perform('Veteran::Service::Representative', representative.representative_id)

        expect(Rails.logger).to have_received(:info).with(
          "No geocodable address for Veteran::Service::Representative##{representative.representative_id}"
        )
      end

      it 'does not update the representative' do
        original_lat = representative.lat
        original_long = representative.long
        original_location = representative.location

        described_class.new.perform('Veteran::Service::Representative', representative.representative_id)

        representative.reload
        expect(representative.lat).to eq(original_lat)
        expect(representative.long).to eq(original_long)
        expect(representative.location).to eq(original_location)
      end
    end

    context 'with sidekiq options' do
      it 'is configured with retry: 3' do
        expect(described_class.sidekiq_options_hash['retry']).to eq(3)
      end
    end
  end
end
