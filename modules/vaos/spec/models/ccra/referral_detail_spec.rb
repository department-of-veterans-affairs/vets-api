# frozen_string_literal: true

require 'rails_helper'

describe Ccra::ReferralDetail do
  # Shared example for testing nil attributes
  shared_examples 'has nil attributes' do
    it 'sets all attributes to nil' do
      # Use reflection to iterate through the object's instance variables
      instance_variables = subject.instance_variables.reject do |v|
        %i[@uuid @appointments @has_appointments].include?(v)
      end
      instance_variables.each do |var|
        value = subject.instance_variable_get(var)
        expect(value).to be_nil, "Expected #{var} to be nil, but got #{value.inspect}"
      end
    end
  end

  describe '#initialize' do
    subject { described_class.new(valid_attributes) }

    let(:valid_attributes) do
      {
        referral_expiration_date: '2024-05-27',
        category_of_care: 'CARDIOLOGY',
        treating_facility: 'VA Medical Center',
        referral_number: 'VA0000005681',
        referral_date: '2024-07-24',
        station_id: '528A6',
        primary_care_provider_npi: '1111111111',
        referring_provider_npi: '2222222222',
        treating_provider_npi: '3333333333',
        referring_facility_info: {
          facility_name: 'Bath VA Medical Center',
          phone: '555-123-4567',
          facility_code: '528A6',
          address: {
            address1: '801 VASSAR DR NE',
            city: 'ALBUQUERQUE',
            state: 'NM',
            zip_code: '87106'
          }
        },
        treating_provider_info: {
          provider_name: 'Dr. Smith',
          provider_npi: '1659458917',
          specialty: 'CARDIOLOGY'
        },
        treating_facility_info: {
          facility_name: 'VA Cardiology Clinic',
          facility_code: '528A7',
          phone: '505-555-1234',
          address: {
            address1: '123 Health Avenue',
            city: 'Albuquerque',
            state: 'NM',
            zip_code: '87107'
          }
        }
      }
    end

    it 'sets all attributes correctly' do
      expect(subject.expiration_date).to eq('2024-05-27')
      expect(subject.category_of_care).to eq('CARDIOLOGY')
      expect(subject.treating_facility).to eq('VA Medical Center')
      expect(subject.referral_number).to eq('VA0000005681')
      expect(subject.referral_date).to eq('2024-07-24')
      expect(subject.station_id).to eq('528A6')
      expect(subject.uuid).to be_nil
      expect(subject.appointments).to eq({})
      expect(subject.has_appointments).to be_nil

      # Provider info (nested from treating_provider_info)
      expect(subject.provider_name).to eq('Dr. Smith')
      expect(subject.provider_npi).to eq('1659458917')
      expect(subject.provider_specialty).to eq('CARDIOLOGY')

      # Root-level NPI fields
      expect(subject.primary_care_provider_npi).to eq('1111111111')
      expect(subject.referring_provider_npi).to eq('2222222222')
      expect(subject.treating_provider_npi).to eq('3333333333')

      # Referring facility info
      expect(subject.referring_facility_name).to eq('Bath VA Medical Center')
      expect(subject.referring_facility_phone).to eq('555-123-4567')
      expect(subject.referring_facility_code).to eq('528A6')
      expect(subject.referring_facility_address).to be_a(Hash)
      expect(subject.referring_facility_address[:street1]).to eq('801 VASSAR DR NE')
      expect(subject.referring_facility_address[:city]).to eq('ALBUQUERQUE')
      expect(subject.referring_facility_address[:state]).to eq('NM')
      expect(subject.referring_facility_address[:zip]).to eq('87106')

      # Treating facility info
      expect(subject.treating_facility_name).to eq('VA Cardiology Clinic')
      expect(subject.treating_facility_code).to eq('528A7')
      expect(subject.treating_facility_phone).to eq('505-555-1234')
      expect(subject.treating_facility_address).to be_a(Hash)
      expect(subject.treating_facility_address[:street1]).to eq('123 Health Avenue')
      expect(subject.treating_facility_address[:city]).to eq('Albuquerque')
      expect(subject.treating_facility_address[:state]).to eq('NM')
      expect(subject.treating_facility_address[:zip]).to eq('87107')
    end

    context 'with empty attributes' do
      subject { described_class.new({}) }

      include_examples 'has nil attributes'
    end

    context 'with nil attributes' do
      subject { described_class.new(nil) }

      include_examples 'has nil attributes'
    end

    context 'with appointments hash' do
      it 'initializes appointments as empty hash by default' do
        detail = described_class.new({})
        expect(detail.appointments).to eq({})
      end

      it 'can be set to appointments data after initialization' do
        detail = described_class.new({})
        detail.appointments = { 'system' => 'VAOS', 'data' => [{ 'id' => '12345' }] }
        detail.has_appointments = true
        expect(detail.appointments).to eq({ 'system' => 'VAOS', 'data' => [{ 'id' => '12345' }] })
        expect(detail.has_appointments).to be(true)
      end

      it 'can be set to empty array after initialization' do
        detail = described_class.new({})
        detail.appointments = []
        detail.has_appointments = false
        expect(detail.appointments).to eq([])
        expect(detail.has_appointments).to be(false)
      end

      it 'can be set to nil after initialization' do
        detail = described_class.new({})
        detail.appointments = nil
        detail.has_appointments = nil
        expect(detail.appointments).to be_nil
        expect(detail.has_appointments).to be_nil
      end
    end

    context 'with partial treating facility info' do
      it 'handles missing address information' do
        attributes = {
          treating_facility_info: {
            facility_name: 'VA Clinic',
            facility_code: '528A8',
            phone: '555-987-6543'
          }
        }
        detail = described_class.new(attributes)
        expect(detail.treating_facility_name).to eq('VA Clinic')
        expect(detail.treating_facility_code).to eq('528A8')
        expect(detail.treating_facility_phone).to eq('555-987-6543')
        expect(detail.treating_facility_address).to be_nil
      end
    end
  end

  describe '#json_serialization' do
    subject { described_class.new }

    let(:json_attributes) do
      {
        'expiration_date' => '2024-05-27',
        'category_of_care' => 'CARDIOLOGY',
        'treating_facility' => 'VA Medical Center',
        'referral_number' => 'VA0000005681',
        'referral_date' => '2024-07-24',
        'station_id' => '528A6',
        'provider_name' => 'Dr. Smith',
        'provider_npi' => '1659458917',
        'provider_specialty' => 'CARDIOLOGY',
        'referring_facility_name' => 'Bath VA Medical Center',
        'referring_facility_phone' => '555-123-4567',
        'referring_facility_code' => '528A6',
        'referring_facility_address' => {
          'street1' => '801 VASSAR DR NE',
          'city' => 'ALBUQUERQUE',
          'state' => 'New Mexico',
          'zip' => '87106'
        },
        'treating_facility_name' => 'VA Cardiology Clinic',
        'treating_facility_code' => '528A7',
        'treating_facility_phone' => '505-555-1234',
        'treating_facility_address' => {
          'street1' => '123 Health Avenue',
          'city' => 'Albuquerque',
          'state' => 'New Mexico',
          'zip' => '87107'
        }
      }
    end

    let(:json_string) { json_attributes.to_json }

    before do
      # Directly set attributes on the instance using public methods
      subject.from_json(json_string)
    end

    it 'can deserialize from JSON' do
      expect(subject).to be_a(described_class)
      expect(subject.expiration_date).to eq('2024-05-27')
      expect(subject.category_of_care).to eq('CARDIOLOGY')
      expect(subject.treating_facility).to eq('VA Medical Center')
      expect(subject.referral_number).to eq('VA0000005681')
      expect(subject.referral_date).to eq('2024-07-24')
      expect(subject.station_id).to eq('528A6')
      expect(subject.appointments).to eq({})
      expect(subject.has_appointments).to be_nil

      # Provider info
      expect(subject.provider_name).to eq('Dr. Smith')
      expect(subject.provider_npi).to eq('1659458917')
      expect(subject.provider_specialty).to eq('CARDIOLOGY')
    end

    it 'symbolizes keys in the address hashes' do
      # Check referring facility address
      expect(subject.referring_facility_address).to be_a(Hash)
      expect(subject.referring_facility_address.keys.all? { |k| k.is_a?(Symbol) }).to be(true)
      expect(subject.referring_facility_address[:street1]).to eq('801 VASSAR DR NE')
      expect(subject.referring_facility_address[:city]).to eq('ALBUQUERQUE')
      expect(subject.referring_facility_address[:state]).to eq('New Mexico')
      expect(subject.referring_facility_address[:zip]).to eq('87106')

      # Check treating facility address
      expect(subject.treating_facility_address).to be_a(Hash)
      expect(subject.treating_facility_address.keys.all? { |k| k.is_a?(Symbol) }).to be(true)
      expect(subject.treating_facility_address[:street1]).to eq('123 Health Avenue')
      expect(subject.treating_facility_address[:city]).to eq('Albuquerque')
      expect(subject.treating_facility_address[:state]).to eq('New Mexico')
      expect(subject.treating_facility_address[:zip]).to eq('87107')
    end

    context 'with invalid JSON' do
      let(:invalid_json) { 'invalid json' }

      it 'handles invalid JSON gracefully' do
        model = described_class.new
        # This uses ActiveModel::Serializers::JSON's from_json method
        expect { model.from_json(invalid_json) }.to raise_error(JSON::ParserError)
      end
    end
  end

  describe '#selected_npi_for_eps' do
    subject { described_class.new(attributes) }

    let(:user) { double('User', account_uuid: '1234', flipper_id: '1234') }

    context 'with all NPI fields populated' do
      let(:attributes) do
        {
          primary_care_provider_npi: '1111111111',
          referring_provider_npi: '2222222222',
          treating_provider_npi: '3333333333',
          treating_provider_info: {
            provider_npi: '4444444444'
          }
        }
      end

      context 'when primary care NPI flag is enabled' do
        before do
          allow(Flipper).to receive(:enabled?)
            .with(:va_online_scheduling_use_primary_care_npi, user)
            .and_return(true)
          allow(Flipper).to receive(:enabled?)
            .with(:va_online_scheduling_use_referring_provider_npi, user)
            .and_return(false)
        end

        it 'returns the primary care provider NPI' do
          expect(subject.selected_npi_for_eps(user)).to eq('1111111111')
        end
      end

      context 'when referring provider NPI flag is enabled' do
        before do
          allow(Flipper).to receive(:enabled?)
            .with(:va_online_scheduling_use_primary_care_npi, user)
            .and_return(false)
          allow(Flipper).to receive(:enabled?)
            .with(:va_online_scheduling_use_referring_provider_npi, user)
            .and_return(true)
        end

        it 'returns the referring provider NPI' do
          expect(subject.selected_npi_for_eps(user)).to eq('2222222222')
        end
      end

      context 'when both flags are enabled (primary care takes priority)' do
        before do
          allow(Flipper).to receive(:enabled?)
            .with(:va_online_scheduling_use_primary_care_npi, user)
            .and_return(true)
          allow(Flipper).to receive(:enabled?)
            .with(:va_online_scheduling_use_referring_provider_npi, user)
            .and_return(true)
        end

        it 'returns the primary care provider NPI' do
          expect(subject.selected_npi_for_eps(user)).to eq('1111111111')
        end
      end

      context 'when no flags are enabled (default behavior)' do
        before do
          allow(Flipper).to receive(:enabled?)
            .with(:va_online_scheduling_use_primary_care_npi, user)
            .and_return(false)
          allow(Flipper).to receive(:enabled?)
            .with(:va_online_scheduling_use_referring_provider_npi, user)
            .and_return(false)
        end

        it 'returns the treating provider NPI from root level' do
          expect(subject.selected_npi_for_eps(user)).to eq('3333333333')
        end
      end
    end

    context 'with fallback to nested provider_npi' do
      context 'when primary care flag is enabled but primary care NPI is blank' do
        let(:attributes) do
          {
            primary_care_provider_npi: '',
            referring_provider_npi: '2222222222',
            treating_provider_npi: '3333333333',
            treating_provider_info: {
              provider_npi: '4444444444'
            }
          }
        end

        before do
          allow(Flipper).to receive(:enabled?)
            .with(:va_online_scheduling_use_primary_care_npi, user)
            .and_return(true)
          allow(Flipper).to receive(:enabled?)
            .with(:va_online_scheduling_use_referring_provider_npi, user)
            .and_return(false)
        end

        it 'falls back to nested treating provider NPI' do
          expect(subject.selected_npi_for_eps(user)).to eq('4444444444')
        end
      end

      context 'when referring flag is enabled but referring NPI is nil' do
        let(:attributes) do
          {
            primary_care_provider_npi: '1111111111',
            referring_provider_npi: nil,
            treating_provider_npi: '3333333333',
            treating_provider_info: {
              provider_npi: '4444444444'
            }
          }
        end

        before do
          allow(Flipper).to receive(:enabled?)
            .with(:va_online_scheduling_use_primary_care_npi, user)
            .and_return(false)
          allow(Flipper).to receive(:enabled?)
            .with(:va_online_scheduling_use_referring_provider_npi, user)
            .and_return(true)
        end

        it 'falls back to nested treating provider NPI' do
          expect(subject.selected_npi_for_eps(user)).to eq('4444444444')
        end
      end

      context 'when treating root NPI is blank (default case)' do
        let(:attributes) do
          {
            primary_care_provider_npi: '1111111111',
            referring_provider_npi: '2222222222',
            treating_provider_npi: '',
            treating_provider_info: {
              provider_npi: '4444444444'
            }
          }
        end

        before do
          allow(Flipper).to receive(:enabled?)
            .with(:va_online_scheduling_use_primary_care_npi, user)
            .and_return(false)
          allow(Flipper).to receive(:enabled?)
            .with(:va_online_scheduling_use_referring_provider_npi, user)
            .and_return(false)
        end

        it 'falls back to nested treating provider NPI' do
          expect(subject.selected_npi_for_eps(user)).to eq('4444444444')
        end
      end
    end

    context 'when user is nil' do
      let(:user) { nil }
      let(:attributes) do
        {
          primary_care_provider_npi: '1111111111',
          referring_provider_npi: '2222222222',
          treating_provider_npi: '3333333333',
          treating_provider_info: {
            provider_npi: '4444444444'
          }
        }
      end

      it 'uses default behavior (treating root NPI)' do
        expect(subject.selected_npi_for_eps(user)).to eq('3333333333')
      end
    end

    context 'when all NPIs are blank' do
      let(:attributes) do
        {
          primary_care_provider_npi: '',
          referring_provider_npi: nil,
          treating_provider_npi: '',
          treating_provider_info: {
            provider_npi: nil
          }
        }
      end

      before do
        allow(Flipper).to receive(:enabled?)
          .with(:va_online_scheduling_use_primary_care_npi, user)
          .and_return(false)
        allow(Flipper).to receive(:enabled?)
          .with(:va_online_scheduling_use_referring_provider_npi, user)
          .and_return(false)
      end

      it 'returns nil' do
        expect(subject.selected_npi_for_eps(user)).to be_nil
      end
    end
  end

  describe '#selected_npi_source' do
    subject { described_class.new(attributes) }

    let(:user) { double('User', account_uuid: '1234', flipper_id: '1234') }

    context 'with all NPI fields populated' do
      let(:attributes) do
        {
          primary_care_provider_npi: '1111111111',
          referring_provider_npi: '2222222222',
          treating_provider_npi: '3333333333',
          treating_provider_info: {
            provider_npi: '4444444444'
          }
        }
      end

      it 'returns :primary_care when primary care flag is enabled' do
        allow(Flipper).to receive(:enabled?)
          .with(:va_online_scheduling_use_primary_care_npi, user)
          .and_return(true)
        allow(Flipper).to receive(:enabled?)
          .with(:va_online_scheduling_use_referring_provider_npi, user)
          .and_return(false)

        expect(subject.selected_npi_source(user)).to eq(:primary_care)
      end

      it 'returns :referring when referring flag is enabled' do
        allow(Flipper).to receive(:enabled?)
          .with(:va_online_scheduling_use_primary_care_npi, user)
          .and_return(false)
        allow(Flipper).to receive(:enabled?)
          .with(:va_online_scheduling_use_referring_provider_npi, user)
          .and_return(true)

        expect(subject.selected_npi_source(user)).to eq(:referring)
      end

      it 'returns :treating_root when no flags are enabled' do
        allow(Flipper).to receive(:enabled?)
          .with(:va_online_scheduling_use_primary_care_npi, user)
          .and_return(false)
        allow(Flipper).to receive(:enabled?)
          .with(:va_online_scheduling_use_referring_provider_npi, user)
          .and_return(false)

        expect(subject.selected_npi_source(user)).to eq(:treating_root)
      end
    end

    context 'when selected NPI is blank and falls back to nested' do
      let(:attributes) do
        {
          primary_care_provider_npi: '',
          referring_provider_npi: '2222222222',
          treating_provider_npi: '3333333333',
          treating_provider_info: {
            provider_npi: '4444444444'
          }
        }
      end

      it 'returns :treating_nested when primary care flag is enabled but blank' do
        allow(Flipper).to receive(:enabled?)
          .with(:va_online_scheduling_use_primary_care_npi, user)
          .and_return(true)
        allow(Flipper).to receive(:enabled?)
          .with(:va_online_scheduling_use_referring_provider_npi, user)
          .and_return(false)

        expect(subject.selected_npi_source(user)).to eq(:treating_nested)
      end

      it 'returns :treating_nested when treating root is blank' do
        allow(Flipper).to receive(:enabled?)
          .with(:va_online_scheduling_use_primary_care_npi, user)
          .and_return(false)
        allow(Flipper).to receive(:enabled?)
          .with(:va_online_scheduling_use_referring_provider_npi, user)
          .and_return(false)

        attributes[:treating_provider_npi] = ''

        expect(subject.selected_npi_source(user)).to eq(:treating_nested)
      end
    end
  end
end
