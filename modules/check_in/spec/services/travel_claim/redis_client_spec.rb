# frozen_string_literal: true

require 'rails_helper'

describe TravelClaim::RedisClient do
  subject { described_class }

  let(:redis_client) { subject.build }
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }
  let(:redis_token_expiry) { 59.minutes }
  let(:appt_data_expiry) { 12.hours }

  let(:uuid) { '755f64db-336f-4614-a3eb-15f732d48de1' }
  let(:patient_icn) { '2113957154V785237' }
  let(:mobile_phone) { '7141234567' }
  let(:station_number) { '500' }
  let(:patient_cell_phone) { '1234567890' }
  let(:facility_type) { 'abc' }

  let(:appointment_identifiers) do
    {
      data: {
        id: uuid,
        type: :appointment_identifier,
        attributes: { patientDFN: '123', stationNo: station_number, icn: patient_icn, mobilePhone: mobile_phone,
                      patientCellPhone: patient_cell_phone, facilityType: facility_type }
      }
    }
  end

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)
    Rails.cache.clear
  end

  describe 'attributes' do
    it 'responds to settings' do
      expect(redis_client.respond_to?(:settings)).to be(true)
    end

    it 'gets redis_token_expiry from settings' do
      expect(redis_client.redis_token_expiry).to eq(redis_token_expiry)
    end
  end

  describe '.build' do
    it 'returns an instance of RedisClient' do
      expect(redis_client).to be_an_instance_of(TravelClaim::RedisClient)
    end
  end

  describe '#token' do
    context 'when cache does not exist' do
      it 'returns nil' do
        expect(redis_client.token).to be_nil
      end
    end

    context 'when cache exists' do
      before do
        Rails.cache.write(
          'token',
          '12345',
          namespace: 'check-in-btsss-cache',
          expires_in: redis_token_expiry
        )
      end

      it 'returns the cached value' do
        expect(redis_client.token).to eq('12345')
      end
    end

    context 'when cache has expired' do
      before do
        Rails.cache.write(
          'token',
          '67890',
          namespace: 'check-in-btsss-cache',
          expires_in: redis_token_expiry
        )
      end

      it 'returns nil' do
        Timecop.travel(redis_token_expiry.from_now) do
          expect(redis_client.token).to be_nil
        end
      end
    end
  end

  describe '#save_token' do
    let(:token) { '12345' }

    it 'saves the value in cache' do
      expect(redis_client.save_token(token:)).to be(true)

      val = Rails.cache.read(
        'token',
        namespace: 'check-in-btsss-cache'
      )
      expect(val).to eq(token)
    end
  end

  describe '#icn' do
    context 'when cache does not exist' do
      it 'returns nil' do
        expect(redis_client.icn(uuid:)).to be_nil
      end
    end

    context 'when cache exists' do
      before do
        Rails.cache.write(
          "check_in_lorota_v2_appointment_identifiers_#{uuid}",
          appointment_identifiers.to_json,
          namespace: 'check-in-lorota-v2-cache',
          expires_in: appt_data_expiry
        )
      end

      it 'returns the cached value' do
        expect(redis_client.icn(uuid:)).to eq(patient_icn)
      end
    end

    context 'when cache has expired' do
      before do
        Rails.cache.write(
          "check_in_lorota_v2_appointment_identifiers_#{uuid}",
          appointment_identifiers.to_json,
          namespace: 'check-in-lorota-v2-cache',
          expires_in: appt_data_expiry
        )
      end

      it 'returns nil' do
        Timecop.travel(appt_data_expiry.from_now) do
          expect(redis_client.icn(uuid:)).to be_nil
        end
      end
    end
  end

  describe '#mobile_phone' do
    before do
      Rails.cache.write(
        "check_in_lorota_v2_appointment_identifiers_#{uuid}",
        appointment_identifiers.to_json,
        namespace: 'check-in-lorota-v2-cache',
        expires_in: appt_data_expiry
      )
    end

    it 'returns the cached value' do
      expect(redis_client.mobile_phone(uuid:)).to eq(mobile_phone)
    end
  end

  describe '#station_number' do
    before do
      Rails.cache.write(
        "check_in_lorota_v2_appointment_identifiers_#{uuid}",
        appointment_identifiers.to_json,
        namespace: 'check-in-lorota-v2-cache',
        expires_in: appt_data_expiry
      )
    end

    it 'returns the cached value' do
      expect(redis_client.station_number(uuid:)).to eq(station_number)
    end
  end

  describe '#patient_cell_phone' do
    before do
      Rails.cache.write(
        "check_in_lorota_v2_appointment_identifiers_#{uuid}",
        appointment_identifiers.to_json,
        namespace: 'check-in-lorota-v2-cache',
        expires_in: appt_data_expiry
      )
    end

    it 'returns the cached value' do
      expect(redis_client.patient_cell_phone(uuid:)).to eq(patient_cell_phone)
    end
  end

  describe '#facility_type' do
    before do
      Rails.cache.write(
        "check_in_lorota_v2_appointment_identifiers_#{uuid}",
        appointment_identifiers.to_json,
        namespace: 'check-in-lorota-v2-cache',
        expires_in: appt_data_expiry
      )
    end

    context 'when cache exists' do
      it 'returns the cached value' do
        expect(redis_client.facility_type(uuid:)).to eq(facility_type)
      end
    end
  end

  describe '#fetch_attribute' do
    context 'when cache does not exist' do
      it 'returns nil' do
        expect(redis_client.fetch_attribute(uuid:, attribute: :icn)).to be_nil
      end
    end

    context 'when cache exists' do
      before do
        Rails.cache.write(
          "check_in_lorota_v2_appointment_identifiers_#{uuid}",
          appointment_identifiers.to_json,
          namespace: 'check-in-lorota-v2-cache',
          expires_in: appt_data_expiry
        )
      end

      it 'returns the cached value' do
        expect(redis_client.fetch_attribute(uuid:, attribute: :icn)).to eq(patient_icn)
      end
    end
  end
end
