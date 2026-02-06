# frozen_string_literal: true

require 'rails_helper'

describe Veteran::Service::Representative, type: :model do
  let(:identity) { create(:user_identity) }

  describe 'individual record' do
    it 'is valid with valid attributes' do
      expect(Veteran::Service::Representative.new(representative_id: '12345', poa_codes: ['000'])).to be_valid
    end

    it 'is not valid without a poa' do
      representative = Veteran::Service::Representative.new(representative_id: '67890', poa_codes: nil)
      expect(representative).not_to be_valid
    end
  end

  def basic_attributes
    {
      representative_id: SecureRandom.hex(8),
      first_name: identity.first_name,
      last_name: identity.last_name
    }
  end

  describe 'finding by identity' do
    let(:representative) do
      create(:representative,
             basic_attributes)
    end

    before do
      identity
      representative
    end

    describe 'finding by the name' do
      it 'finds a user' do
        expect(Veteran::Service::Representative.for_user(
          first_name: identity.first_name,
          last_name: identity.last_name
        ).id).to eq(representative.id)
      end

      it 'handles a nil value without throwing an exception' do
        expect(Veteran::Service::Representative.for_user(
                 first_name: identity.first_name,
                 last_name: nil
               )).to be_nil
      end
    end

    it 'finds right user when 2 with the same name exist' do
      create(:representative,
             basic_attributes)
      expect(Veteran::Service::Representative.for_user(
        first_name: identity.first_name,
        last_name: identity.last_name
      ).id).to eq(representative.id)
    end

    describe '#all_for_user' do
      it 'handles a nil value without throwing an exception' do
        expect(Veteran::Service::Representative.all_for_user(
                 first_name: identity.first_name,
                 last_name: nil,
                 middle_initial: 'J',
                 poa_code: '016'
               )).to eq([])
      end
    end
  end

  describe '.find_within_max_distance' do
    before do
      create(:representative, representative_id: '456', long: -77.050552, lat: 38.820450,
                              location: 'POINT(-77.050552 38.820450)') # ~6 miles from Washington, D.C.

      create(:representative, representative_id: '789', long: -76.609383, lat: 39.299236,
                              location: 'POINT(-76.609383 39.299236)') # ~35 miles from Washington, D.C.

      create(:representative, representative_id: '123', long: -77.466316, lat: 38.309875,
                              location: 'POINT(-77.466316 38.309875)') # ~47 miles from Washington, D.C.

      create(:representative, representative_id: '246', long: -76.3483, lat: 39.5359,
                              location: 'POINT(-76.3483 39.5359)') # ~57 miles from Washington, D.C.
    end

    context 'when there are representatives within the max search distance' do
      it 'returns all representatives located within the default max distance' do
        # check within 50 miles of Washington, D.C.
        results = described_class.find_within_max_distance(-77.0369, 38.9072)

        expect(results.pluck(:representative_id)).to match_array(%w[123 456 789])
      end

      it 'returns all representatives located within the specified max distance' do
        # check within 40 miles of Washington, D.C.
        results = described_class.find_within_max_distance(-77.0369, 38.9072, 64_373.8)

        expect(results.pluck(:representative_id)).to match_array(%w[456 789])
      end
    end

    context 'when there are no representatives within the max search distance' do
      it 'returns an empty array' do
        # check within 1 mile of Washington, D.C.
        results = described_class.find_within_max_distance(-77.0369, 38.9072, 1609.344)

        expect(results).to eq([])
      end
    end
  end

  describe '#organizations' do
    let(:representative) { create(:representative, poa_codes: %w[ABC 123]) }

    context 'when there are no organizations with the representative poa_codes' do
      it 'returns an empty array' do
        expect(representative.organizations).to eq([])
      end
    end

    context 'when there are organizations with the representative poa_codes' do
      it 'a list of those organizations' do
        organization1 = create(:organization, poa: 'ABC')
        organization2 = create(:organization, poa: '123')

        expect(representative.organizations).to contain_exactly(organization1, organization2)
      end
    end
  end

  describe 'callbacks' do
    describe '#set_full_name' do
      context 'creating a new representative' do
        it 'sets the full_name attribute as first_name + last_name' do
          representative = described_class.new(representative_id: 'abc', poa_codes: ['123'], first_name: 'Joe',
                                               last_name: 'Smith')

          expect(representative.full_name).to be_nil

          representative.save!

          expect(representative.reload.full_name).to eq('Joe Smith')
        end
      end

      context 'updating an existing representative' do
        it 'sets the full_name attribute as first_name + last_name' do
          representative = create(:representative, first_name: 'Joe', last_name: 'Smith')

          expect(representative.full_name).to eq('Joe Smith')

          representative.update(first_name: 'Bob')

          expect(representative.reload.full_name).to eq('Bob Smith')
        end
      end

      context 'blank values' do
        context 'when first and last name are blank' do
          it 'sets full_name to empty string' do
            representative = described_class.new(representative_id: 'abc', poa_codes: ['123'], first_name: ' ',
                                                 last_name: ' ')

            representative.save!

            expect(representative.reload.full_name).to eq('')
          end
        end

        context 'when first name is blank' do
          it 'sets full_name to last_name' do
            representative = described_class.new(representative_id: 'abc', poa_codes: ['123'], first_name: ' ',
                                                 last_name: 'Smith')

            representative.save!

            expect(representative.reload.full_name).to eq('Smith')
          end
        end

        context 'when last name is blank' do
          it 'sets full_name to first_name' do
            representative = described_class.new(representative_id: 'abc', poa_codes: ['123'], first_name: 'Bob',
                                                 last_name: ' ')

            representative.save!

            expect(representative.reload.full_name).to eq('Bob')
          end
        end

        context 'when first and last name are present' do
          it 'sets full_name to first_name + last_name' do
            representative = described_class.new(representative_id: 'abc', poa_codes: ['123'], first_name: 'Bob',
                                                 last_name: 'Smith')

            representative.save!

            expect(representative.reload.full_name).to eq('Bob Smith')
          end
        end
      end
    end
  end

  describe '#diff' do
    context 'when there are changes in raw_address' do
      let(:representative) do
        create(:representative,
               raw_address: {
                 'address_line1' => '123 Main St',
                 'address_line2' => 'Apt 1',
                 'address_line3' => nil,
                 'city' => 'Anytown',
                 'state_code' => 'ST',
                 'zip_code' => '12345'
               })
      end
      let(:new_data) do
        {
          raw_address: {
            'address_line1' => '234 Main St',
            'address_line2' => 'Apt 1',
            'address_line3' => nil,
            'city' => 'Anytown',
            'state_code' => 'ST',
            'zip_code' => '12345'
          },
          email: representative.email,
          phone_number: representative.phone_number
        }
      end

      it 'returns a hash indicating changes in address but not email or phone' do
        expect(representative.diff(new_data)).to eq({
                                                      'address_changed' => true,
                                                      'email_changed' => false,
                                                      'phone_number_changed' => false
                                                    })
      end
    end

    context 'when raw_address is nil on both sides' do
      let(:representative) do
        create(:representative,
               raw_address: nil)
      end
      let(:new_data) do
        {
          raw_address: nil,
          email: representative.email,
          phone_number: representative.phone_number
        }
      end

      it 'returns no changes' do
        expect(representative.diff(new_data)).to eq({
                                                      'address_changed' => false,
                                                      'email_changed' => false,
                                                      'phone_number_changed' => false
                                                    })
      end
    end

    context 'when there are changes in email' do
      let(:representative) do
        create(:representative,
               email: 'old@example.com')
      end
      let(:new_data) do
        {
          address: {
            address_line1: representative.address_line1,
            city: representative.city,
            zip_code5: representative.zip_code,
            zip_code4: representative.zip_suffix,
            state_province: { code: representative.state_code }
          },
          email: 'new@example.com',
          phone_number: representative.phone_number
        }
      end

      it 'returns a hash indicating changes in email but not address or phone' do
        expect(representative.diff(new_data)).to eq({
                                                      'address_changed' => false,
                                                      'email_changed' => true,
                                                      'phone_number_changed' => false
                                                    })
      end
    end

    context 'when there are changes in phone' do
      let(:representative) do
        create(:representative,
               phone_number: '1234567890')
      end
      let(:new_data) do
        {
          address: {
            address_line1: representative.address_line1,
            city: representative.city,
            zip_code5: representative.zip_code,
            zip_code4: representative.zip_suffix,
            state_province: { code: representative.state_code }
          },
          email: representative.email,
          phone_number: '0987654321'
        }
      end

      it 'returns a hash indicating changes in phone but not address or email' do
        expect(representative.diff(new_data)).to eq({
                                                      'address_changed' => false,
                                                      'email_changed' => false,
                                                      'phone_number_changed' => true
                                                    })
      end
    end

    context 'when there are no changes to address, email or phone' do
      let(:representative) do
        create(:representative,
               raw_address: {
                 'address_line1' => '123 Main St',
                 'address_line2' => nil,
                 'address_line3' => nil,
                 'city' => 'Anytown',
                 'state_code' => 'ST',
                 'zip_code' => '12345'
               })
      end
      let(:new_data) do
        {
          raw_address: {
            'address_line1' => '123 Main St',
            'address_line2' => nil,
            'address_line3' => nil,
            'city' => 'Anytown',
            'state_code' => 'ST',
            'zip_code' => '12345'
          },
          email: representative.email,
          phone_number: representative.phone_number
        }
      end

      it 'returns a hash indicating no changes in address, email and phone number' do
        expect(representative.diff(new_data)).to eq({
                                                      'address_changed' => false,
                                                      'email_changed' => false,
                                                      'phone_number_changed' => false
                                                    })
      end
    end
  end

  describe '#geocode_and_update_location!' do
    let(:representative) do
      create(:representative,
             representative_id: 'test-rep-123',
             address_line1: '1600 Pennsylvania Ave NW',
             city: 'Washington',
             state_code: 'DC',
             zip_code: '20500')
    end

    let(:geocoding_result) do
      double('Geocoder::Result',
             latitude: 38.8977,
             longitude: -77.0365)
    end

    before do
      allow(Geocoder.config).to receive(:api_key).and_return('test_api_key')
      allow(Geocoder).to receive(:search).and_return([geocoding_result])
    end

    context 'when Geocoder API key is not configured' do
      before do
        allow(Geocoder.config).to receive(:api_key).and_return(nil)
        allow(Geocoder).to receive(:search).and_return([geocoding_result]) # Reset the stub
      end

      it 'returns false immediately without making API calls' do
        expect(representative.geocode_and_update_location!).to be false
        expect(Geocoder).not_to have_received(:search)
      end

      it 'does not modify the record' do
        expect { representative.geocode_and_update_location! }.not_to(change { representative.reload.attributes })
      end
    end

    context 'when Geocoder API key is configured' do
      it 'successfully geocodes and updates location fields' do
        expect(representative.geocode_and_update_location!).to be true

        representative.reload
        expect(representative.lat).to eq(38.8977)
        expect(representative.long).to eq(-77.0365)
        expect(representative.location.x).to eq(-77.0365)
        expect(representative.location.y).to eq(38.8977)
        expect(representative.fallback_location_updated_at).to be_present
      end

      it 'calls Geocoder.search with the built address' do
        representative.geocode_and_update_location!

        expect(Geocoder).to have_received(:search).with('1600 Pennsylvania Ave NW Washington DC 20500')
      end

      it 'sets fallback_location_updated_at timestamp' do
        expect { representative.geocode_and_update_location! }
          .to change { representative.reload.fallback_location_updated_at }
          .from(nil)
          .to(be_within(1.second).of(Time.current))
      end

      it 'clears all location and address fields before geocoding' do
        representative.update!(
          lat: 40.0,
          long: -75.0,
          city: 'Old City',
          state_code: 'XX',
          zip_code: '99999',
          address_line1: 'Old Address',
          raw_address: {
            'address_line1' => '1600 Pennsylvania Ave NW',
            'city' => 'Washington',
            'state_code' => 'DC',
            'zip_code' => '20500'
          }
        )

        representative.geocode_and_update_location!
        representative.reload

        # Verify fields were updated with new geocoded data
        expect(representative.lat).to eq(38.8977)
        expect(representative.long).to eq(-77.0365)
        expect(representative.city).to eq('Washington')
        expect(representative.state_code).to eq('DC')
        expect(representative.zip_code).to eq('20500')
      end
    end

    context 'when geocoding is successful with raw_address' do
      let(:representative) do
        create(:representative,
               representative_id: 'test-rep-456',
               raw_address: {
                 'address_line1' => '1600 Pennsylvania Ave NW',
                 'city' => 'Washington',
                 'state_code' => 'DC',
                 'zip_code' => '20500'
               },
               address_line1: '1600 Pennsylvania Ave NW',
               city: nil,
               state_code: nil,
               zip_code: nil)
      end

      it 'populates city, state_code, and zip_code from raw_address' do
        representative.geocode_and_update_location!
        representative.reload

        expect(representative.city).to eq('Washington')
        expect(representative.state_code).to eq('DC')
        expect(representative.zip_code).to eq('20500')
      end

      it 'updates location fields' do
        representative.geocode_and_update_location!
        representative.reload

        expect(representative.lat).to eq(38.8977)
        expect(representative.long).to eq(-77.0365)
      end
    end

    context 'when no address data is available' do
      let(:representative) do
        create(:representative,
               representative_id: 'test-rep-789',
               address_line1: nil,
               city: nil,
               state_code: nil,
               zip_code: nil)
      end

      it 'returns false without calling Geocoder' do
        expect(representative.geocode_and_update_location!).to be false
        expect(Geocoder).not_to have_received(:search)
      end
    end

    context 'when geocoding returns no results' do
      before do
        allow(Geocoder).to receive(:search).and_return([])
      end

      it 'returns false' do
        expect(representative.geocode_and_update_location!).to be false
      end
    end

    context 'with specific Geocoder error types' do
      before do
        allow(Rails.logger).to receive(:warn)
        allow(Rails.logger).to receive(:error)
      end

      context 'when invalid API key' do
        before do
          allow(Geocoder).to receive(:search).and_raise(Geocoder::InvalidApiKey.new('Invalid API key'))
        end

        it 'logs error and returns false without retry' do
          expect(representative.geocode_and_update_location!).to be false
          expect(Rails.logger).to have_received(:error).with(/API key invalid/)
        end
      end

      context 'when service unavailable' do
        before do
          allow(Geocoder).to receive(:search).and_raise(Geocoder::ServiceUnavailable.new('Service unavailable'))
        end

        it 'logs warning and re-raises for Sidekiq retry' do
          expect { representative.geocode_and_update_location! }
            .to raise_error(Geocoder::ServiceUnavailable)
          expect(Rails.logger).to have_received(:warn).with(/service unavailable/)
        end
      end
    end
  end

  describe '#geocoding_record_id' do
    let(:representative) { create(:representative, representative_id: 'test-rep-999') }

    it 'returns representative_id for error logging' do
      expect(representative.geocoding_record_id).to eq('test-rep-999')
    end
  end

  describe 'associations' do
    it 'has many organization_representatives' do
      assoc = described_class.reflect_on_association(:organization_representatives)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.class_name).to eq('Veteran::Service::OrganizationRepresentative')
      expect(assoc.foreign_key.to_s).to eq('representative_id')
      expect(assoc.options[:primary_key].to_s).to eq('representative_id')
    end

    it 'has many organizations through organization_representatives' do
      assoc = described_class.reflect_on_association(:organizations)
      expect(assoc.macro).to eq(:has_many)
      expect(assoc.options[:through]).to eq(:organization_representatives)
      expect(assoc.options[:source]).to eq(:organization)
    end
  end
end
