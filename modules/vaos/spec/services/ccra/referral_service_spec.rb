# frozen_string_literal: true

require 'rails_helper'

describe Ccra::ReferralService do
  subject { described_class.new(user) }

  let(:user) { double('User', account_uuid: '1234', flipper_id: '1234', icn: '1012845331V153043') }
  let(:session_token) { 'fake-session-token' }
  let(:request_id) { 'request-id' }
  let(:memory_store) { ActiveSupport::Cache.lookup_store(:memory_store) }
  let(:referral_cache) { instance_double(Ccra::RedisClient) }

  let(:user_service) { instance_double(VAOS::UserService, session: session_token) }

  before do
    allow(RequestStore.store).to receive(:[]).with('request_id').and_return(request_id)

    # Mock the session token from UserService
    allow(VAOS::UserService).to receive(:new).and_return(user_service)

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

    context 'when service raises an error with flipper enabled' do
      let(:error_message_with_icn) { "Connection failed for patient #{icn} with invalid status" }
      let(:backend_exception) do
        Common::Exceptions::BackendServiceException.new('VA900', {
                                                          code: 'VA900',
                                                          detail: error_message_with_icn
                                                        })
      end

      before do
        allow_any_instance_of(described_class).to receive(:perform).and_raise(backend_exception)
      end

      context 'when CCRA error logging flipper is enabled' do
        before do
          allow(Flipper).to receive(:enabled?)
            .with(:va_online_scheduling_ccra_error_logging, user)
            .and_return(true)
          allow(Flipper).to receive(:enabled?)
            .with(:logging_data_scrubber)
            .and_return(true)
        end

        it 'logs detailed error information with scrubbed PHI' do
          # Expect the Rails logger to receive the error with scrubbed data
          expect(Rails.logger).to receive(:error) do |message, data|
            expect(message).to eq('Community Care Appointments: Failed to fetch VAOS referral list')
            expect(data[:referral_status]).to eq(referral_status)
            expect(data[:service]).to eq('ccra')
            expect(data[:method]).to eq('get_vaos_referral_list')
            expect(data[:error_class]).to eq('Common::Exceptions::BackendServiceException')
            # The scrub method should have replaced the ICN with [REDACTED]
            expect(data[:error_message]).to include('[REDACTED]')
            expect(data[:error_message]).not_to include(icn)
            expect(data[:error_backtrace]).to be_an(Array)
          end

          expect do
            subject.get_vaos_referral_list(icn, referral_status)
          end.to raise_error(Common::Exceptions::BackendServiceException)
        end

        it 'ensures PHI like ICN numbers are scrubbed from error messages' do
          # Verify the logged message does not contain the actual ICN
          # The scrub method should automatically replace ICN with [REDACTED]
          expect(Rails.logger).to receive(:error) do |message, data|
            expect(message).to eq('Community Care Appointments: Failed to fetch VAOS referral list')
            expect(data[:error_message]).not_to include(icn)
            expect(data[:error_message]).to include('[REDACTED]')
            # Verify the error message contains the scrubbed detail
            expect(data[:error_message]).to match(/Connection failed for patient \[REDACTED\]/)
          end

          expect do
            subject.get_vaos_referral_list(icn, referral_status)
          end.to raise_error(Common::Exceptions::BackendServiceException)
        end
      end

      context 'when CCRA error logging flipper is disabled' do
        before do
          allow(Flipper).to receive(:enabled?)
            .with(:va_online_scheduling_ccra_error_logging, user)
            .and_return(false)
        end

        it 'does not log detailed error information' do
          expect(Rails.logger).not_to receive(:error)
            .with('CCRA: Failed to fetch VAOS referral list', anything)

          expect do
            subject.get_vaos_referral_list(icn, referral_status)
          end.to raise_error(Common::Exceptions::BackendServiceException)
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

    context 'NPI field logging' do
      let(:id) { 'test_referral_123' }
      let(:response_double) { double('Response', body: response_body) }

      before do
        allow_any_instance_of(Ccra::ReferralService).to receive(:perform).and_return(response_double)
        allow(Ccra::ReferralDetail).to receive(:new).and_return(referral_detail)
      end

      context 'when all NPI fields are present' do
        let(:response_body) do
          {
            primary_care_provider_npi: '1111111111',
            referring_provider_npi: '2222222222',
            treating_provider_npi: '3333333333',
            referring_provider_info: {
              provider_npi: '5555555555'
            },
            treating_provider_info: {
              provider_npi: '4444444444'
            },
            category_of_care: 'CARDIOLOGY',
            referral_number: 'VA0000005681'
          }
        end

        it 'logs all NPI fields with correct presence flags and last 3 digits' do
          expect(Rails.logger).to receive(:info) do |message, data|
            expect(message).to eq('Community Care Appointments: CCRA referral NPI fields')
            expect(data[:referral_id_last3]).to eq('123')

            # Root-level NPIs
            expect(data[:primary_care_provider_npi_present]).to be true
            expect(data[:primary_care_provider_npi_last3]).to eq('111')
            expect(data[:referring_provider_npi_present]).to be true
            expect(data[:referring_provider_npi_last3]).to eq('222')
            expect(data[:treating_provider_npi_present]).to be true
            expect(data[:treating_provider_npi_last3]).to eq('333')

            # Nested NPIs
            expect(data[:referring_provider_info_npi_present]).to be true
            expect(data[:referring_provider_info_npi_last3]).to eq('555')
            expect(data[:treating_provider_info_npi_present]).to be true
            expect(data[:treating_provider_info_npi_last3]).to eq('444')
          end

          subject.get_referral(id, icn)
        end
      end

      context 'when only some NPI fields are present' do
        let(:response_body) do
          {
            primary_care_provider_npi: '',
            referring_provider_npi: '2222222222',
            treating_provider_npi: '3333333333',
            treating_provider_info: {
              provider_npi: '4444444444'
            },
            category_of_care: 'CARDIOLOGY',
            referral_number: 'VA0000005681'
          }
        end

        it 'logs presence/absence correctly for each field' do
          expect(Rails.logger).to receive(:info) do |message, data|
            expect(message).to eq('Community Care Appointments: CCRA referral NPI fields')
            expect(data[:primary_care_provider_npi_present]).to be false
            expect(data[:primary_care_provider_npi_last3]).to be_nil
            expect(data[:referring_provider_npi_present]).to be true
            expect(data[:referring_provider_npi_last3]).to eq('222')
            expect(data[:treating_provider_npi_present]).to be true
            expect(data[:treating_provider_npi_last3]).to eq('333')
            expect(data[:referring_provider_info_npi_present]).to be false
            expect(data[:treating_provider_info_npi_present]).to be true
            expect(data[:treating_provider_info_npi_last3]).to eq('444')
          end

          subject.get_referral(id, icn)
        end
      end

      context 'when no NPI fields are present' do
        let(:response_body) do
          {
            category_of_care: 'CARDIOLOGY',
            referral_number: 'VA0000005681'
          }
        end

        it 'logs absence of all NPI fields' do
          expect(Rails.logger).to receive(:info) do |message, data|
            expect(message).to eq('Community Care Appointments: CCRA referral NPI fields')
            expect(data[:primary_care_provider_npi_present]).to be false
            expect(data[:referring_provider_npi_present]).to be false
            expect(data[:treating_provider_npi_present]).to be false
            expect(data[:referring_provider_info_npi_present]).to be false
            expect(data[:treating_provider_info_npi_present]).to be false
          end

          subject.get_referral(id, icn)
        end
      end

      context 'when NPI fields contain short values' do
        let(:response_body) do
          {
            primary_care_provider_npi: '12',
            referring_provider_npi: 'X',
            treating_provider_npi: '99',
            treating_provider_info: {
              provider_npi: 'AB'
            },
            category_of_care: 'CARDIOLOGY',
            referral_number: 'VA0000005681'
          }
        end

        it 'handles short NPI values correctly (returns full value when less than 3 chars)' do
          expect(Rails.logger).to receive(:info) do |_message, data|
            expect(data[:primary_care_provider_npi_last3]).to eq('12')
            expect(data[:referring_provider_npi_last3]).to eq('X')
            expect(data[:treating_provider_npi_last3]).to eq('99')
            expect(data[:treating_provider_info_npi_last3]).to eq('AB')
          end

          subject.get_referral(id, icn)
        end
      end

      context 'when response contains unexpected NPI fields' do
        let(:response_body) do
          {
            primary_care_provider_npi: '1111111111',
            treating_provider_npi: '3333333333',
            treating_provider_info: {
              provider_npi: '4444444444'
            },
            unexpected_npi_field: '9999999999',
            nested_data: {
              another_npi: '8888888888'
            },
            category_of_care: 'CARDIOLOGY',
            referral_number: 'VA0000005681'
          }
        end

        it 'finds and logs additional NPI fields' do
          expect(Rails.logger).to receive(:info) do |message, data|
            expect(message).to eq('Community Care Appointments: CCRA referral NPI fields')
            expect(data[:additional_npi_fields]).to be_an(Array)

            # Check that unexpected NPIs are captured
            unexpected_npi = data[:additional_npi_fields].find { |f| f[:field] == 'unexpected_npi_field' }
            expect(unexpected_npi).to be_present
            expect(unexpected_npi[:last3]).to eq('999')

            another_npi = data[:additional_npi_fields].find { |f| f[:field] == 'nested_data.another_npi' }
            expect(another_npi).to be_present
            expect(another_npi[:last3]).to eq('888')
          end

          subject.get_referral(id, icn)
        end
      end

      context 'when referral data is cached' do
        let(:response_body) { {} }

        before do
          allow(referral_cache).to receive(:fetch_referral_data)
            .with(id:, icn:)
            .and_return(referral_detail)
        end

        it 'does not log NPI fields' do
          expect(Rails.logger).not_to receive(:info).with(
            'Community Care Appointments: CCRA referral NPI fields',
            anything
          )

          subject.get_referral(id, icn)
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

  describe '#get_cached_referral_data' do
    let(:id) { '984_646372' }
    let(:icn) { '1012845331V153043' }
    let(:referral_detail) do
      instance_double(Ccra::ReferralDetail,
                      category_of_care: 'CARDIOLOGY',
                      referral_number: 'VA0000005681')
    end

    context 'when cached data exists' do
      before do
        allow(referral_cache).to receive(:fetch_referral_data)
          .with(id:, icn:)
          .and_return(referral_detail)
      end

      it 'returns the cached referral detail' do
        result = subject.get_cached_referral_data(id, icn)
        expect(result).to eq(referral_detail)
      end

      it 'calls referral_cache.fetch_referral_data with correct parameters' do
        expect(referral_cache).to receive(:fetch_referral_data).with(id:, icn:)
        subject.get_cached_referral_data(id, icn)
      end
    end

    context 'when cached data does not exist' do
      before do
        allow(referral_cache).to receive(:fetch_referral_data)
          .with(id:, icn:)
          .and_return(nil)
      end

      it 'returns nil' do
        result = subject.get_cached_referral_data(id, icn)
        expect(result).to be_nil
      end
    end
  end
end
