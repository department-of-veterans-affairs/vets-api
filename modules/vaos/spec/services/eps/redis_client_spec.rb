# frozen_string_literal: true

require 'rails_helper'

describe Eps::RedisClient do
  subject { described_class.new }

  let(:redis_client) { subject }
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }
  let(:redis_token_expiry) { 59.minutes }

  let(:referral_number) { '12345' }
  let(:provider_id) { '67890' }
  let(:appointment_type_id) { 'abc' }
  let(:start_date) { '2023-12-31' }
  let(:end_date) { '2023-12-31' }

  let(:referral_identifiers) do
    {
      data: {
        id: referral_number,
        type: :referral_identifier,
        attributes: { provider_id:, appointment_type_id:, start_date:, end_date: }
      }
    }.to_json
  end

  let(:referral_response) do
    {
      data: {
        attributes: {
          referral: {
            patient: {
              birthSex: 'F',
              dob: '1953-04-01',
              email: 'valid@somedomain.com',
              first_name: 'Judy',
              gender: 'F',
              home_address: {
                address1: '20 W 34TH ST APT 2368A',
                city: 'NEW YORK',
                country: 'United States',
                state: 'New York',
                zip_code: '10118'
              },
              icn: '1012845331V153043',
              last_name: 'MORRISON',
              m_name: 'Snow',
              patient_id: '466',
              ssn: '796061976',
              telephone_business: '(703)652-0000',
              telephone_home: '+1 (510) 4104799',
              telephone_mobile: '+1 (317) 9087069'
            }
          }
        }
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

  describe '#provider_id' do
    context 'when cache does not exist' do
      it 'returns nil' do
        expect(redis_client.provider_id(referral_number:)).to be_nil
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
        expect(redis_client.provider_id(referral_number:)).to eq(provider_id)
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
          expect(redis_client.provider_id(referral_number:)).to be_nil
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

  describe '#fetch_attribute' do
    context 'when cache does not exist' do
      it 'returns nil' do
        expect(redis_client.fetch_attribute(referral_number:, attribute: :provider_id)).to be_nil
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
        expect(redis_client.fetch_attribute(referral_number:, attribute: :provider_id)).to eq(provider_id)
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
          provider_id:,
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

  describe '#referral_read' do
    context 'when cache exists' do
      before do
        redis_client.referral_write(referral_number:, referral: referral_response)
      end

      it 'reads from cache' do
        expect(redis_client.referral_read(referral_number:)).to eq(referral_response)
      end
    end

    context 'when cache has expired' do
      before do
        redis_client.referral_write(referral_number:, referral: referral_response)
      end

      it 'reads from cache' do
        Timecop.travel(redis_token_expiry.from_now) do
          expect(redis_client.referral_read(referral_number:)).to be_nil
        end
      end
    end

    context 'when cache is empty' do
      it 'returns nil' do
        expect(redis_client.referral_read(referral_number:)).to be_nil
      end
    end
  end

  describe '#referral_write' do
    context 'when referral object is written to cache' do
      it 'returns true' do
        expect(redis_client.referral_write(referral_number:, referral: referral_response)).to be(true)
      end
    end
  end
end
