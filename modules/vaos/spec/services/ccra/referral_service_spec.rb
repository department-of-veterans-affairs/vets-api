# frozen_string_literal: true

require 'rails_helper'

describe Ccra::ReferralService do
  subject { described_class.new(user) }

  let(:user) { double('User', account_uuid: '1234', flipper_id: '1234', icn: '1012845331V153043') }
  let(:session_token) { 'fake-session-token' }
  let(:request_id) { 'request-id' }
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }
  let(:referral_cache) { instance_double(Ccra::RedisClient) }

  before do
    allow(RequestStore.store).to receive(:[]).with('request_id').and_return(request_id)

    # Mock the session token from UserService
    allow_any_instance_of(VAOS::UserService).to receive(:session).with(user).and_return(session_token)

    # Set up memory store for caching in tests
    allow(Rails).to receive(:cache).and_return(memory_store)
    Rails.cache.clear

    # Mock the RedisClient
    allow(Ccra::RedisClient).to receive(:new).and_return(referral_cache)
    allow(referral_cache).to receive_messages(
      save_referral_data: true,
      fetch_referral_data: nil,
      save_booking_start_time: true,
      fetch_booking_start_time: nil
    )

    Settings.vaos ||= OpenStruct.new
    Settings.vaos.ccra ||= OpenStruct.new
    Settings.vaos.ccra.tap do |ccra|
      ccra.api_url = 'http://ccra.api.example.com'
      ccra.base_path = 'vaos/v1/patients'
    end
  end

  describe '#get_vaos_referral_list' do
    let(:icn) { '1012845331V153043' }
    let(:referral_status) { "'S','BP','AP','AC','A','I'" }

    context 'with successful response', :vcr do
      it 'returns an array of ReferralListEntry objects' do
        VCR.use_cassette('vaos/ccra/post_referral_list_success') do
          result = subject.get_vaos_referral_list(icn, referral_status)
          expect(result).to be_an(Array)
          expect(result.size).to eq(3)
          expect(result.first).to be_a(Ccra::ReferralListEntry)
          expect(result.first.referral_number).to eq('VA0000005681')
          expect(result.first.category_of_care).to eq('CARDIOLOGY')
          expect(result.first.referral_consult_id).to eq('984_646372')
        end
      end
    end

    context 'with empty response', :vcr do
      let(:referral_status) { 'INVALID' }

      it 'returns an empty array' do
        VCR.use_cassette('vaos/ccra/post_referral_list_empty') do
          result = subject.get_vaos_referral_list(icn, referral_status)
          expect(result).to be_an(Array)
          expect(result).to be_empty
        end
      end
    end

    context 'with error response', :vcr do
      let(:icn) { 'invalid' }

      it 'raises a BackendServiceException' do
        VCR.use_cassette('vaos/ccra/post_referral_list_error') do
          expect { subject.get_vaos_referral_list(icn, referral_status) }
            .to raise_error(Common::Exceptions::BackendServiceException)
        end
      end
    end
  end

  describe '#get_referral' do
    let(:id) { '984_646372' }
    let(:icn) { '1012845331V153043' }
    let(:referral_detail) do
      instance_double(Ccra::ReferralDetail,
                      category_of_care: 'CARDIOLOGY',
                      referral_number: 'VA0000005681')
    end

    context 'when cached data exists' do
      before do
        allow(referral_cache).to receive(:fetch_referral_data).with(id:, icn:).and_return(referral_detail)
      end

      it 'returns the cached referral detail and updates booking start time' do
        Timecop.freeze(Time.current) do
          expected_start_time = Time.current.to_f
          allow(referral_detail).to receive(:referral_number).and_return('VA0000005681')
          expect(referral_cache).to receive(:save_booking_start_time)
            .with(referral_number: 'VA0000005681', booking_start_time: expected_start_time)
            .and_return(true)

          result = subject.get_referral(id, icn)
          expect(result).to eq(referral_detail)
        end
      end
    end

    context 'with successful response', :vcr do
      it 'returns a ReferralDetail object with correct attributes' do
        VCR.use_cassette('vaos/ccra/post_get_referral_success') do
          result = subject.get_referral(id, icn)

          # Verify the result is a real ReferralDetail object
          expect(result).to be_a(Ccra::ReferralDetail)
          expect(result.category_of_care).to eq('CARDIOLOGY')
          expect(result.referral_number).to eq('VA0000005681')
        end
      end

      it 'caches the referral data and booking start time' do
        VCR.use_cassette('vaos/ccra/post_get_referral_success') do
          Timecop.freeze(Time.current) do
            expected_start_time = Time.current.to_f

            expect(referral_cache).to receive(:save_referral_data).with(
              id:,
              icn:,
              referral_data: instance_of(Ccra::ReferralDetail)
            ).and_return(true)

            # Verify the referral data after the call
            allow(referral_cache).to receive(:save_referral_data) do |args|
              referral = args[:referral_data]
              expect(referral.category_of_care).to eq('CARDIOLOGY')
              expect(referral.referral_number).to eq('VA0000005681')
              expect(referral.booking_start_time).to eq(expected_start_time)
              true
            end

            expect(referral_cache).to receive(:save_booking_start_time).with(
              referral_number: 'VA0000005681',
              booking_start_time: expected_start_time
            ).and_return(true)

            subject.get_referral(id, icn)
          end
        end
      end
    end

    context 'when referral not found', :vcr do
      let(:id) { 'invalid_id' }

      it 'raises not found error' do
        VCR.use_cassette('vaos/ccra/post_get_referral_not_found') do
          expect { subject.get_referral(id, icn) }
            .to raise_error(Common::Exceptions::BackendServiceException)
        end
      end
    end

    context 'with error response', :vcr do
      let(:id) { 'error_id' }

      it 'raises a BackendServiceException' do
        VCR.use_cassette('vaos/ccra/post_get_referral_error') do
          expect { subject.get_referral(id, icn) }
            .to raise_error(Common::Exceptions::BackendServiceException)
        end
      end
    end
  end

  describe '#get_booking_start_time' do
    let(:id) { '984_646372' }
    let(:icn) { '1012845331V153043' }
    let(:referral_number) { 'VA0000005681' }
    let(:booking_start_time) { Time.current.to_f }
    let(:referral_detail) do
      instance_double(Ccra::ReferralDetail,
                      referral_number:)
    end

    context 'when referral exists in cache' do
      before do
        allow(referral_cache).to receive(:fetch_referral_data)
          .with(id:, icn:)
          .and_return(referral_detail)
      end

      it 'returns the booking start time when it exists' do
        allow(referral_cache).to receive(:fetch_booking_start_time)
          .with(referral_number:)
          .and_return(booking_start_time)

        result = subject.get_booking_start_time(id, icn)
        expect(result).to eq(booking_start_time)
      end

      it 'returns nil and logs warning when booking start time not found' do
        allow(referral_cache).to receive(:fetch_booking_start_time)
          .with(referral_number:)
          .and_return(nil)

        expect(Rails.logger).to receive(:warn).with(
          'Community Care Appointments: Referral booking start time not found.'
        )
        result = subject.get_booking_start_time(id, icn)
        expect(result).to be_nil
      end
    end
  end
end
