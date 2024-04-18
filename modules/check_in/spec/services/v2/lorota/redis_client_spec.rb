# frozen_string_literal: true

require 'rails_helper'

describe V2::Lorota::RedisClient do
  subject { described_class }

  let(:opts) do
    {
      data: {
        uuid: 'd602d9eb-9a31-484f-9637-13ab0b507e0d',
        last4: '1234',
        last_name: 'Johnson'
      },
      jwt: nil
    }
  end
  let(:check_in) { CheckIn::V2::Session.build(opts) }
  let(:redis_client) { subject.build }
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }
  let(:redis_expiry_time) { 12.hours }
  let(:retry_attempt_expiry) { 7.days }

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
    it 'responds to lorota_v2_settings' do
      expect(redis_client.respond_to?(:lorota_v2_settings)).to be(true)
    end

    it 'gets redis_session_prefix from settings' do
      expect(redis_client.redis_session_prefix).to eq('check_in_lorota_v2')
    end

    it 'gets redis_token_expiry from settings' do
      expect(redis_client.redis_token_expiry).to eq(43_200)
    end

    it 'responds to authentication_settings' do
      expect(redis_client.respond_to?(:authentication_settings)).to be(true)
    end

    it 'gets retry_attempt_expiry from settings' do
      expect(redis_client.retry_attempt_expiry).to eq(604_800)
    end
  end

  describe '.build' do
    it 'returns an instance of RedisClient' do
      expect(redis_client).to be_an_instance_of(V2::Lorota::RedisClient)
    end
  end

  describe '#get' do
    let(:uuid) { 'd602d9eb-9a31-484f-9637-13ab0b507e0d' }

    context 'when cache exists' do
      before do
        Rails.cache.write(
          "check_in_lorota_v2_#{uuid}_read.full",
          '12345',
          namespace: 'check-in-lorota-v2-cache',
          expires_in: redis_expiry_time
        )
      end

      it 'returns the cached value' do
        expect(redis_client.get(check_in_uuid: uuid)).to eq('12345')
      end
    end

    context 'when cache expires' do
      let(:uuid) { Faker::Internet.uuid }

      before do
        Rails.cache.write(
          "check_in_lorota_v2_#{uuid}_read.full",
          '52617',
          namespace: 'check-in-lorota-v2-cache',
          expires_in: redis_expiry_time
        )
      end

      it 'returns nil' do
        Timecop.travel(redis_expiry_time.from_now) do
          expect(redis_client.get(check_in_uuid: uuid)).to eq(nil)
        end
      end
    end

    context 'when cache does not exist' do
      it 'returns nil' do
        expect(redis_client.get(check_in_uuid: uuid)).to eq(nil)
      end
    end
  end

  describe '#save' do
    let(:uuid) { 'd602d9eb-9a31-484f-9637-13ab0b507e0d' }
    let(:token) { '12345' }

    it 'saves the value in cache' do
      expect(redis_client.save(check_in_uuid: uuid, token:)).to eq(true)

      val = Rails.cache.read(
        "check_in_lorota_v2_#{uuid}_read.full",
        namespace: 'check-in-lorota-v2-cache'
      )
      expect(val).to eq(token)
    end
  end

  describe '#retry_attempt_count' do
    let(:uuid) { 'd602d9eb-9a31-484f-9637-13ab0b507e0d' }

    context 'when cache exists' do
      before do
        Rails.cache.write(
          "authentication_retry_limit_#{uuid}",
          '2',
          namespace: 'check-in-lorota-v2-cache',
          expires_in: retry_attempt_expiry
        )
      end

      it 'returns the cached value' do
        expect(redis_client.retry_attempt_count(uuid:)).to eq('2')
      end
    end

    context 'when cache expires' do
      let(:uuid) { Faker::Internet.uuid }

      before do
        Rails.cache.write(
          "authentication_retry_limit_#{uuid}",
          '2',
          namespace: 'check-in-lorota-v2-cache',
          expires_in: retry_attempt_expiry
        )
      end

      it 'returns nil' do
        Timecop.travel(retry_attempt_expiry.from_now) do
          expect(redis_client.retry_attempt_count(uuid:)).to eq(nil)
        end
      end
    end

    context 'when cache does not exist' do
      it 'returns nil' do
        expect(redis_client.retry_attempt_count(uuid:)).to eq(nil)
      end
    end
  end

  describe '#save_retry_attempt_count' do
    let(:uuid) { 'd602d9eb-9a31-484f-9637-13ab0b507e0d' }
    let(:retry_count) { 3 }

    it 'saves the value in cache' do
      expect(redis_client.save_retry_attempt_count(uuid:, retry_count:)).to eq(true)

      val = Rails.cache.read(
        "authentication_retry_limit_#{uuid}",
        namespace: 'check-in-lorota-v2-cache'
      )
      expect(val).to eq(retry_count)
    end
  end

  describe '#icn' do
    context 'when cache does not exist' do
      it 'returns nil' do
        expect(redis_client.icn(uuid:)).to eq(nil)
      end
    end

    context 'when cache exists' do
      before do
        Rails.cache.write(
          "check_in_lorota_v2_appointment_identifiers_#{uuid}",
          appointment_identifiers.to_json,
          namespace: 'check-in-lorota-v2-cache',
          expires_in: redis_expiry_time
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
          expires_in: redis_expiry_time
        )
      end

      it 'returns nil' do
        Timecop.travel(redis_expiry_time.from_now) do
          expect(redis_client.icn(uuid:)).to eq(nil)
        end
      end
    end
  end
end
