# frozen_string_literal: true

require 'rails_helper'

describe Eps::RedisClient do
  subject { described_class.new }

  let(:redis_client) { subject }
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }
  let(:redis_token_expiry) { 59.minutes }

  let(:referral_number) { '12345' }
  let(:npi) { '1234567890' }
  let(:appointment_type_id) { 'abc' }
  let(:start_date) { '2023-12-31' }
  let(:end_date) { '2023-12-31' }

  let(:referral_identifiers) do
    {
      data: {
        id: referral_number,
        type: :referral_identifier,
        attributes: { npi:, appointment_type_id:, start_date:, end_date: }
      }
    }.to_json
  end

  before do
    allow(Rails).to receive(:cache).and_return(memory_store)
    Rails.cache.clear
  end

  describe 'attributes' do
    it 'responds to settings' do
      expect(redis_client.respond_to?(:settings)).to be(true)
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
          namespace: 'vaos-eps-cache',
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
          namespace: 'vaos-eps-cache',
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
        namespace: 'vaos-eps-cache'
      )
      expect(val).to eq(token)
    end
  end

  describe '#npi' do
    context 'when cache does not exist' do
      it 'returns nil' do
        expect(redis_client.npi(referral_number:)).to be_nil
      end
    end

    context 'when cache exists' do
      before do
        Rails.cache.write(
          "vaos_eps_referral_identifier_#{referral_number}",
          referral_identifiers,
          namespace: 'vaos-eps-cache',
          expires_in: redis_token_expiry
        )
      end

      it 'returns the cached value' do
        expect(redis_client.npi(referral_number:)).to eq(npi)
      end
    end

    context 'when cache has expired' do
      before do
        Rails.cache.write(
          "vaos_eps_referral_identifier_#{referral_number}",
          referral_identifiers,
          namespace: 'vaos-eps-cache',
          expires_in: redis_token_expiry
        )
      end

      it 'returns nil' do
        Timecop.travel(redis_token_expiry.from_now) do
          expect(redis_client.npi(referral_number:)).to be_nil
        end
      end
    end
  end

  describe '#appointment_type_id' do
    before do
      Rails.cache.write(
        "vaos_eps_referral_identifier_#{referral_number}",
        referral_identifiers,
        namespace: 'vaos-eps-cache',
        expires_in: redis_token_expiry
      )
    end

    it 'returns the cached value' do
      expect(redis_client.appointment_type_id(referral_number:)).to eq(appointment_type_id)
    end
  end

  describe '#end_date' do
    before do
      Rails.cache.write(
        "vaos_eps_referral_identifier_#{referral_number}",
        referral_identifiers,
        namespace: 'vaos-eps-cache',
        expires_in: redis_token_expiry
      )
    end

    it 'returns the cached value' do
      expect(redis_client.end_date(referral_number:)).to eq(end_date)
    end
  end

  describe '#save_referral_data' do
    let(:referral_id) { '67890' }
    let(:provider_npi) { 'NPI123456' }
    let(:referral) do
      instance_double(
        Ccra::ReferralDetail,
        station_id: npi,
        appointment_type_id:,
        expiration_date: end_date,
        provider_npi:,
        referral_date: start_date
      )
    end

    context 'when all required fields are present' do
      it 'saves the referral data to cache and returns true' do
        expect(redis_client.save_referral_data(referral_id:, referral:)).to be(true)

        # Verify the data was saved correctly
        saved_data = Rails.cache.read(
          "vaos_eps_referral_identifier_#{referral_id}",
          namespace: 'vaos-eps-cache'
        )

        # Verify the saved data has the expected structure
        expect(saved_data).to be_a(String)
        parsed_data = Oj.load(saved_data).with_indifferent_access
        expect(parsed_data).to have_key(:data)
        expect(parsed_data[:data]).to have_key(:attributes)

        attributes = parsed_data[:data][:attributes]
        expect(attributes[:npi]).to eq(provider_npi)
        expect(attributes[:appointment_type_id]).to eq(appointment_type_id)
        expect(attributes[:end_date]).to eq(end_date)
        expect(attributes[:start_date]).to eq(start_date)
      end
    end

    context 'when required fields are missing' do
      let(:incomplete_referral) do
        instance_double(
          Ccra::ReferralDetail,
          station_id: npi,
          appointment_type_id: nil,  # Missing required field
          expiration_date: end_date,
          provider_npi: nil,         # Missing required field
          referral_date: start_date
        )
      end

      it 'does not save to cache and returns false' do
        expect(redis_client.save_referral_data(referral_id:, referral: incomplete_referral)).to be(false)

        # Verify no data was saved
        saved_data = Rails.cache.read(
          "vaos_eps_referral_identifier_#{referral_id}",
          namespace: 'vaos-eps-cache'
        )
        expect(saved_data).to be_nil
      end
    end

    context 'when referral_id is nil' do
      it 'returns false without attempting to save' do
        expect(redis_client.save_referral_data(referral_id: nil, referral:)).to be(false)
      end
    end

    context 'when referral is nil' do
      it 'returns false without attempting to save' do
        expect(redis_client.save_referral_data(referral_id:, referral: nil)).to be(false)
      end
    end
  end

  describe '#fetch_attribute' do
    context 'when cache does not exist' do
      it 'returns nil' do
        expect(redis_client.fetch_attribute(referral_number:, attribute: :npi)).to be_nil
      end
    end

    context 'when cache exists' do
      before do
        Rails.cache.write(
          "vaos_eps_referral_identifier_#{referral_number}",
          referral_identifiers,
          namespace: 'vaos-eps-cache',
          expires_in: redis_token_expiry
        )
      end

      it 'returns the cached value' do
        expect(redis_client.fetch_attribute(referral_number:, attribute: :npi)).to eq(npi)
      end
    end
  end

  describe '#fetch_referral_attributes' do
    context 'when cache does not exist' do
      it 'returns nil' do
        expect(redis_client.fetch_referral_attributes(referral_number:)).to be_nil
      end
    end

    context 'when cache exists' do
      before do
        Rails.cache.write(
          "vaos_eps_referral_identifier_#{referral_number}",
          referral_identifiers,
          namespace: 'vaos-eps-cache',
          expires_in: redis_token_expiry
        )
      end

      it 'returns all cached attributes' do
        expected_attributes = {
          npi:,
          appointment_type_id:,
          start_date:,
          end_date:
        }

        referral_attrs = redis_client.fetch_referral_attributes(referral_number:)
        expect(referral_attrs).to eq(expected_attributes.with_indifferent_access)
      end
    end

    context 'when cache has expired' do
      before do
        Rails.cache.write(
          "vaos_eps_referral_identifier_#{referral_number}",
          referral_identifiers,
          namespace: 'vaos-eps-cache',
          expires_in: redis_token_expiry
        )
      end

      it 'returns nil' do
        Timecop.travel(redis_token_expiry.from_now) do
          expect(redis_client.fetch_referral_attributes(referral_number:)).to be_nil
        end
      end
    end
  end
end
