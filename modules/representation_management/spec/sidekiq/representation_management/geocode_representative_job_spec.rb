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
      allow(Rails.logger).to receive(:error)
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
        allow_any_instance_of(AccreditedIndividual).to receive(:geocode_and_update_location!) do
          individual.update(lat: 38.8977, long: -77.0365, location: 'POINT (-77.0365 38.8977)')
        end

        described_class.new.perform('AccreditedIndividual', individual.id)

        individual.reload
        expect(individual.lat).to eq(38.8977)
        expect(individual.long).to eq(-77.0365)
        expect(individual.location.to_s).to eq('POINT (-77.0365 38.8977)')
      end

      context 'when individual has no geocodable address' do
        let!(:individual_no_address) do
          create(:accredited_individual,
                 address_line1: nil,
                 city: nil,
                 state_code: nil,
                 zip_code: nil)
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

      context 'when Mapbox API key is not configured' do
        before do
          allow(Geocoder.config).to receive(:api_key).and_return(nil)
        end

        it 'completes successfully without errors' do
          expect do
            described_class.new.perform('AccreditedIndividual', individual.id)
          end.not_to raise_error
        end

        it 'returns false from geocode_and_update_location!' do
          expect(individual.geocode_and_update_location!).to be false
        end

        it 'does not make any geocoding API calls' do
          described_class.new.perform('AccreditedIndividual', individual.id)
          expect(Geocoder).not_to have_received(:search)
        end
      end
    end

    context 'when geocoding fails with an error' do
      let!(:individual) do
        create(:accredited_individual,
               address_line1: '123 Main St',
               city: 'Anytown',
               state_code: 'ST',
               zip_code: '12345')
      end

      before do
        allow_any_instance_of(AccreditedIndividual)
          .to receive(:geocode_and_update_location!)
          .and_raise(StandardError.new('Database error'))
      end

      it 'logs the error and re-raises for Sidekiq retry' do
        expect do
          described_class.new.perform('AccreditedIndividual', individual.id)
        end.to raise_error(StandardError, 'Database error')

        expect(Rails.logger).to have_received(:error).with(
          /Geocode job failed for AccreditedIndividual##{individual.id}/
        )
      end
    end

    context 'with invalid model class name' do
      let!(:individual) do
        create(:accredited_individual)
      end

      it 'raises an error' do
        expect do
          described_class.new.perform('InvalidModel', individual.id)
        end.to raise_error(NameError)
      end
    end

    context 'when geocoding returns no results' do
      let!(:individual) do
        create(:accredited_individual,
               address_line1: 'Invalid Address XYZ123',
               city: 'Nowhere',
               state_code: 'ZZ',
               zip_code: '00000')
      end

      before do
        allow(Geocoder).to receive(:search).and_return([])
      end

      it 'does not update the individual' do
        original_lat = individual.lat
        original_long = individual.long
        original_location = individual.location

        described_class.new.perform('AccreditedIndividual', individual.id)

        individual.reload
        expect(individual.lat).to eq(original_lat)
        expect(individual.long).to eq(original_long)
        expect(individual.location).to eq(original_location)
      end
    end

    context 'with sidekiq options' do
      it 'is configured with retry: 3' do
        expect(described_class.sidekiq_options_hash['retry']).to eq(3)
      end
    end
  end
end
