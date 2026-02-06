# frozen_string_literal: true

require 'rails_helper'
require 'veteran_status_card/service'

RSpec.describe VeteranStatusCard::Service do
  subject { described_class.new(user) }

  let(:user) { build(:user, :loa3) }

  # Mock responses
  let(:vet_verification_service) { instance_double(VeteranVerification::Service) }
  let(:military_personnel_service) { instance_double(VAProfile::MilitaryPersonnel::Service) }
  let(:lighthouse_disabilities_provider) { instance_double(LighthouseRatedDisabilitiesProvider) }

  # Default mock data
  let(:vet_verification_response) do
    {
      'data' => {
        'attributes' => {
          'veteran_status' => veteran_status,
          'not_confirmed_reason' => not_confirmed_reason
        },
        'message' => error_message,
        'title' => error_title,
        'status' => error_status
      }
    }
  end

  let(:veteran_status) { 'confirmed' }
  let(:not_confirmed_reason) { nil }
  let(:error_message) { '' }
  let(:error_title) { '' }
  let(:error_status) { '' }

  let(:dod_service_summary_response) do
    instance_double(
      VAProfile::MilitaryPersonnel::DodServiceSummaryResponse,
      dod_service_summary: dod_service_summary_model
    )
  end

  let(:dod_service_summary_model) do
    VAProfile::Models::DodServiceSummary.new(
      dod_service_summary_code: ssc_code,
      calculation_model_version: '1.0',
      effective_start_date: '2020-01-01'
    )
  end

  let(:ssc_code) { 'A1' }

  let(:disability_rating) { 50 }

  before do
    allow(VeteranVerification::Service).to receive(:new).and_return(vet_verification_service)
    allow(vet_verification_service).to receive(:get_vet_verification_status).and_return(vet_verification_response)

    allow(VAProfile::MilitaryPersonnel::Service).to receive(:new).and_return(military_personnel_service)
    allow(military_personnel_service).to receive(:get_dod_service_summary).and_return(dod_service_summary_response)

    allow(LighthouseRatedDisabilitiesProvider).to receive(:new).and_return(lighthouse_disabilities_provider)
    allow(lighthouse_disabilities_provider).to receive(:get_combined_disability_rating).and_return(disability_rating)
  end

  describe '#initialize' do
    before do
      allow(StatsD).to receive(:increment)
    end

    context 'when user is valid' do
      it 'logs STATSD_TOTAL' do
        described_class.new(user)

        expect(StatsD).to have_received(:increment).with('veteran_status_card.total')
      end

      it 'does not log STATSD_FAILURE' do
        described_class.new(user)

        expect(StatsD).not_to have_received(:increment).with('veteran_status_card.failure')
      end
    end

    context 'when user is nil' do
      it 'logs STATSD_TOTAL and STATSD_FAILURE' do
        expect { described_class.new(nil) }.to raise_error(ArgumentError)

        expect(StatsD).to have_received(:increment).with('veteran_status_card.total')
        expect(StatsD).to have_received(:increment).with('veteran_status_card.failure')
      end

      it 'raises an argument error' do
        expect { described_class.new(nil) }.to raise_error(ArgumentError, 'User cannot be nil')
      end
    end

    context 'when user edipi and icn are nil' do
      before do
        allow(user).to receive_messages(edipi: nil, icn: nil)
      end

      it 'logs STATSD_TOTAL and STATSD_FAILURE' do
        expect { described_class.new(user) }.to raise_error(ArgumentError)

        expect(StatsD).to have_received(:increment).with('veteran_status_card.total')
        expect(StatsD).to have_received(:increment).with('veteran_status_card.failure')
      end

      it 'raises an argument error' do
        expect { described_class.new(user) }.to raise_error(ArgumentError, 'User missing required fields')
      end
    end
  end

  describe 'protected methods' do
    describe '#statsd_key_prefix' do
      it 'returns the base prefix' do
        expect(subject.send(:statsd_key_prefix)).to eq('veteran_status_card')
      end
    end

    describe '#service_name' do
      it 'returns the base service name' do
        expect(subject.send(:service_name)).to eq('[VeteranStatusCard::Service]')
      end
    end
  end

  describe 'private logging methods' do
    before do
      allow(StatsD).to receive(:increment)
      allow(Rails.logger).to receive(:info)
    end

    describe '#log_statsd' do
      it 'increments StatsD with the full key using statsd_key_prefix' do
        subject.send(:log_statsd, 'test_key')

        expect(StatsD).to have_received(:increment).with('veteran_status_card.test_key')
      end
    end

    describe '#log_vsc_result' do
      context 'when confirmed is true' do
        it 'logs STATSD_ELIGIBLE' do
          subject.send(:log_vsc_result, confirmed: true)

          expect(StatsD).to have_received(:increment).with('veteran_status_card.eligible')
        end

        it 'logs info with confirmed veteran_status' do
          subject.send(:log_vsc_result, confirmed: true)

          expect(Rails.logger).to have_received(:info).with(
            '[VeteranStatusCard::Service] VSC Card Result',
            hash_including(veteran_status: 'confirmed')
          )
        end
      end

      context 'when confirmed is false (default)' do
        let(:not_confirmed_reason) { 'MORE_RESEARCH_REQUIRED' }

        it 'logs STATSD_INELIGIBLE' do
          subject.send(:log_vsc_result)

          expect(StatsD).to have_received(:increment).with('veteran_status_card.ineligible')
        end

        it 'logs info with not confirmed veteran_status and reason' do
          subject.send(:log_vsc_result)

          expect(Rails.logger).to have_received(:info).with(
            '[VeteranStatusCard::Service] VSC Card Result',
            hash_including(
              veteran_status: 'not confirmed',
              not_confirmed_reason: 'MORE_RESEARCH_REQUIRED'
            )
          )
        end
      end

      it 'includes service_summary_code in log' do
        subject.send(:log_vsc_result, confirmed: true)

        expect(Rails.logger).to have_received(:info).with(
          '[VeteranStatusCard::Service] VSC Card Result',
          hash_including(service_summary_code: ssc_code)
        )
      end

      context 'confirmation_status StatsD logging' do
        it 'logs the confirmation_status as a StatsD metric' do
          subject.instance_variable_set(:@confirmation_status, 'test_confirmation_status')

          subject.send(:log_vsc_result, confirmed: false)

          expect(StatsD).to have_received(:increment).with('veteran_status_card.test_confirmation_status')
        end

        it 'logs the confirmation_status even when confirmed' do
          subject.instance_variable_set(:@confirmation_status, 'test_confirmation_status')

          subject.send(:log_vsc_result, confirmed: true)

          expect(StatsD).to have_received(:increment).with('veteran_status_card.test_confirmation_status')
        end

        it 'logs the default NO_SSC_CHECK_MESSAGE when not otherwise set' do
          subject.send(:log_vsc_result, confirmed: true)

          expect(StatsD).to have_received(:increment).with('veteran_status_card.no_ssc_check')
        end
      end
    end

    describe '#confirmation_status_upcase' do
      context 'when @confirmation_status is set' do
        it 'returns the uppercase @confirmation_status' do
          subject.instance_variable_set(:@confirmation_status, 'dishonorable_ssc')

          result = subject.send(:confirmation_status_upcase)

          expect(result).to eq('DISHONORABLE_SSC')
        end
      end

      context 'when @confirmation_status has default value' do
        it 'returns the uppercase default value' do
          result = subject.send(:confirmation_status_upcase)

          expect(result).to eq('NO_SSC_CHECK')
        end
      end
    end
  end

  describe '#status_card' do
    describe 'StatsD logging' do
      before do
        allow(StatsD).to receive(:increment)
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:error)
      end

      context 'when veteran is eligible' do
        let(:veteran_status) { 'confirmed' }

        it 'logs STATSD_ELIGIBLE via log_vsc_result' do
          subject.status_card

          expect(StatsD).to have_received(:increment).with('veteran_status_card.eligible')
        end

        it 'logs VSC Card Result info' do
          subject.status_card

          expect(Rails.logger).to have_received(:info).with(
            '[VeteranStatusCard::Service] VSC Card Result',
            hash_including(
              veteran_status: 'confirmed',
              service_summary_code: ssc_code
            )
          )
        end
      end

      context 'when veteran is not eligible' do
        let(:veteran_status) { 'not confirmed' }
        let(:not_confirmed_reason) { 'PERSON_NOT_FOUND' }

        it 'logs STATSD_INELIGIBLE via log_vsc_result' do
          subject.status_card

          expect(StatsD).to have_received(:increment).with('veteran_status_card.ineligible')
        end

        it 'logs VSC Card Result info with reason' do
          subject.status_card

          expect(Rails.logger).to have_received(:info).with(
            '[VeteranStatusCard::Service] VSC Card Result',
            hash_including(
              veteran_status: 'not confirmed',
              not_confirmed_reason: 'PERSON_NOT_FOUND',
              service_summary_code: ssc_code
            )
          )
        end
      end

      describe 'ineligibility reason StatsD logging' do
        context 'with DISHONORABLE SSC code' do
          let(:veteran_status) { 'not confirmed' }
          let(:not_confirmed_reason) { 'MORE_RESEARCH_REQUIRED' }
          let(:ssc_code) { 'A5' }

          it 'logs DISHONORABLE_SSC_MESSAGE to StatsD' do
            subject.status_card

            expect(StatsD).to have_received(:increment).with('veteran_status_card.dishonorable_ssc')
          end
        end

        context 'with INELIGIBLE_SERVICE SSC code' do
          let(:veteran_status) { 'not confirmed' }
          let(:not_confirmed_reason) { 'MORE_RESEARCH_REQUIRED' }
          let(:ssc_code) { 'G2' }

          it 'logs INELIGIBLE_SSC_MESSAGE to StatsD' do
            subject.status_card

            expect(StatsD).to have_received(:increment).with('veteran_status_card.ineligible_ssc')
          end
        end

        context 'with UNKNOWN_SERVICE SSC code' do
          let(:veteran_status) { 'not confirmed' }
          let(:not_confirmed_reason) { 'MORE_RESEARCH_REQUIRED' }
          let(:ssc_code) { 'U' }

          it 'logs UNKNOWN_SSC_MESSAGE to StatsD' do
            subject.status_card

            expect(StatsD).to have_received(:increment).with('veteran_status_card.unknown_ssc')
          end
        end

        context 'with EDIPI_NO_PNL SSC code' do
          let(:veteran_status) { 'not confirmed' }
          let(:not_confirmed_reason) { 'MORE_RESEARCH_REQUIRED' }
          let(:ssc_code) { 'X' }

          it 'logs EDIPI_NO_PNL_SSC_MESSAGE to StatsD' do
            subject.status_card

            expect(StatsD).to have_received(:increment).with('veteran_status_card.edipi_no_pnl_ssc')
          end
        end

        context 'with CURRENTLY_SERVING SSC code' do
          let(:veteran_status) { 'not confirmed' }
          let(:not_confirmed_reason) { 'MORE_RESEARCH_REQUIRED' }
          let(:ssc_code) { 'D' }

          it 'logs CURRENTLY_SERVING_SSC_MESSAGE to StatsD' do
            subject.status_card

            expect(StatsD).to have_received(:increment).with('veteran_status_card.currently_serving_ssc')
          end
        end

        context 'with ERROR SSC code' do
          let(:veteran_status) { 'not confirmed' }
          let(:not_confirmed_reason) { 'MORE_RESEARCH_REQUIRED' }
          let(:ssc_code) { 'VNA' }

          it 'logs ERROR_SSC_MESSAGE to StatsD' do
            subject.status_card

            expect(StatsD).to have_received(:increment).with('veteran_status_card.error_ssc')
          end
        end

        context 'with uncaught SSC code' do
          let(:veteran_status) { 'not confirmed' }
          let(:not_confirmed_reason) { 'MORE_RESEARCH_REQUIRED' }
          let(:ssc_code) { 'UNKNOWN_CODE' }

          it 'logs UNCAUGHT_SSC_MESSAGE to StatsD' do
            subject.status_card

            expect(StatsD).to have_received(:increment).with('veteran_status_card.uncaught_ssc')
          end
        end

        context 'with PERSON_NOT_FOUND reason (no @ineligible_message set)' do
          let(:veteran_status) { 'not confirmed' }
          let(:not_confirmed_reason) { 'PERSON_NOT_FOUND' }

          it 'logs the vet_verification_status reason to StatsD' do
            subject.status_card

            expect(StatsD).to have_received(:increment).with('veteran_status_card.person_not_found')
          end
        end

        context 'with ERROR reason (no @ineligible_message set)' do
          let(:veteran_status) { 'not confirmed' }
          let(:not_confirmed_reason) { 'ERROR' }
          let(:error_title) { 'Error' }
          let(:error_message) { 'An error occurred' }
          let(:error_status) { 'error' }

          it 'logs the vet_verification_status reason to StatsD' do
            subject.status_card

            expect(StatsD).to have_received(:increment).with('veteran_status_card.error')
          end
        end
      end

      context 'when an exception occurs' do
        let(:veteran_status) { 'confirmed' }

        before do
          allow(user).to receive(:full_name_normalized).and_raise(StandardError.new('Test error'))
        end

        it 'logs STATSD_FAILURE' do
          subject.status_card

          expect(StatsD).to have_received(:increment).with('veteran_status_card.failure')
        end

        it 'logs error with service name' do
          subject.status_card

          expect(Rails.logger).to have_received(:error).with(
            '[VeteranStatusCard::Service] error: Test error',
            hash_including(:backtrace)
          )
        end
      end
    end

    context 'when veteran is eligible' do
      context 'via vet_verification_eligible? (confirmed status)' do
        let(:veteran_status) { 'confirmed' }

        it 'returns veteran_status_card with full veteran data' do
          result = subject.status_card

          expect(result[:type]).to eq('veteran_status_card')
          expect(result[:attributes][:full_name]).to be_a(String)
          expect(result[:attributes][:full_name]).to be_present
          expect(result[:attributes][:disability_rating]).to eq(50)
          expect(result[:attributes][:edipi]).to eq(user.edipi)
          expect(result[:attributes][:veteran_status]).to eq('confirmed')
          expect(result[:attributes][:not_confirmed_reason]).to be_nil
          expect(result[:attributes][:service_summary_code]).to eq(ssc_code)
        end
      end

      context 'via ssc_eligible? with MORE_RESEARCH_REQUIRED reason' do
        let(:veteran_status) { 'not confirmed' }
        let(:not_confirmed_reason) { 'MORE_RESEARCH_REQUIRED' }

        {
          'AD_DSCH_VAL_SSC' => described_class::AD_DSCH_VAL_SSC_CODES,
          'AD_VAL_PREV_QUAL_SSC' => described_class::AD_VAL_PREV_QUAL_SSC_CODES,
          'AD_VAL_PREV_RES_GRD_SSC' => described_class::AD_VAL_PREV_RES_GRD_SSC_CODES,
          'AD_UNCHAR_DSCH_SSC' => described_class::AD_UNCHAR_DSCH_SSC_CODES,
          'VAL_PREV_QUAL_SSC' => described_class::VAL_PREV_QUAL_SSC
        }.each do |category, codes|
          context "with #{category} codes" do
            codes.each do |code|
              context "with SSC code #{code}" do
                let(:ssc_code) { code }

                it 'returns veteran_status_card for confirmed SSC code' do
                  result = subject.status_card

                  expect(result[:type]).to eq('veteran_status_card')
                  expect(result[:attributes][:full_name]).to be_a(String)
                  expect(result[:attributes][:full_name]).to be_present
                  expect(result[:attributes][:veteran_status]).to eq('confirmed')
                  expect(result[:attributes][:not_confirmed_reason]).to eq('MORE_RESEARCH_REQUIRED')
                  expect(result[:attributes][:service_summary_code]).to eq(code)
                  expect(result[:attributes][:confirmation_status]).to eq(category)
                end
              end
            end
          end
        end
      end

      context 'via ssc_eligible? with NOT_TITLE_38 reason' do
        let(:veteran_status) { 'not confirmed' }
        let(:not_confirmed_reason) { 'NOT_TITLE_38' }

        {
          'AD_DSCH_VAL_SSC' => described_class::AD_DSCH_VAL_SSC_CODES,
          'AD_VAL_PREV_QUAL_SSC' => described_class::AD_VAL_PREV_QUAL_SSC_CODES,
          'AD_VAL_PREV_RES_GRD_SSC' => described_class::AD_VAL_PREV_RES_GRD_SSC_CODES,
          'AD_UNCHAR_DSCH_SSC' => described_class::AD_UNCHAR_DSCH_SSC_CODES,
          'VAL_PREV_QUAL_SSC' => described_class::VAL_PREV_QUAL_SSC
        }.each do |category, codes|
          context "with #{category} codes" do
            codes.each do |code|
              context "with SSC code #{code}" do
                let(:ssc_code) { code }

                it 'returns veteran_status_card for confirmed SSC code' do
                  result = subject.status_card

                  expect(result[:type]).to eq('veteran_status_card')
                  expect(result[:attributes][:veteran_status]).to eq('confirmed')
                  expect(result[:attributes][:not_confirmed_reason]).to eq('NOT_TITLE_38')
                  expect(result[:attributes][:service_summary_code]).to eq(code)
                  expect(result[:attributes][:confirmation_status]).to eq(category)
                end
              end
            end
          end
        end
      end

      context 'disability rating scenarios' do
        let(:veteran_status) { 'confirmed' }

        it 'returns disability rating from Lighthouse' do
          expect(lighthouse_disabilities_provider).to receive(:get_combined_disability_rating).and_return(75)

          result = subject.status_card

          expect(result[:type]).to eq('veteran_status_card')
          expect(result[:attributes][:disability_rating]).to eq(75)
        end

        it 'returns nil when disability rating is nil' do
          allow(lighthouse_disabilities_provider).to receive(:get_combined_disability_rating).and_return(nil)

          result = subject.status_card

          expect(result[:type]).to eq('veteran_status_card')
          expect(result[:attributes][:disability_rating]).to be_nil
        end
      end

      context 'complete data structure validation' do
        let(:veteran_status) { 'confirmed' }

        it 'returns all expected fields with correct types' do
          result = subject.status_card

          expect(result).to be_a(Hash)
          expect(result.keys).to contain_exactly(:type, :attributes)

          expect(result[:type]).to eq('veteran_status_card')

          expect(result[:attributes]).to be_a(Hash)
          expect(result[:attributes].keys).to contain_exactly(:full_name, :disability_rating,
                                                              :edipi, :veteran_status,
                                                              :not_confirmed_reason, :confirmation_status,
                                                              :service_summary_code)
          expect(result[:attributes][:full_name]).to be_a(String)
          expect(result[:attributes][:disability_rating]).to be_a(Integer)
          expect(result[:attributes][:edipi]).to eq(user.edipi)
          expect(result[:attributes][:veteran_status]).to eq('confirmed')
          expect(result[:attributes][:not_confirmed_reason]).to be_nil
          expect(result[:attributes][:service_summary_code]).to eq(ssc_code)
        end
      end
    end

    context 'when veteran is not eligible' do
      let(:veteran_status) { 'not confirmed' }

      context 'with PERSON_NOT_FOUND reason' do
        let(:not_confirmed_reason) { 'PERSON_NOT_FOUND' }
        let(:error_title) { 'Person Not Found Title' }
        let(:error_message) { 'Person not found message' }
        let(:error_status) { 'error' }

        it 'returns veteran_status_alert with error details' do
          result = subject.status_card

          expect(result[:type]).to eq('veteran_status_alert')
          expect(result[:attributes][:header]).to eq('Person Not Found Title')
          expect(result[:attributes][:body]).to eq('Person not found message')
          expect(result[:attributes][:alert_type]).to eq('error')
          expect(result[:attributes][:veteran_status]).to eq('not confirmed')
          expect(result[:attributes][:not_confirmed_reason]).to eq('PERSON_NOT_FOUND')
          expect(result[:attributes][:service_summary_code]).to eq(ssc_code)
        end
      end

      context 'with ERROR reason' do
        let(:not_confirmed_reason) { 'ERROR' }
        let(:error_title) { 'Error Title' }
        let(:error_message) { 'Error message' }
        let(:error_status) { 'error' }

        it 'returns veteran_status_alert with error details' do
          result = subject.status_card

          expect(result[:type]).to eq('veteran_status_alert')
          expect(result[:attributes][:header]).to eq('Error Title')
          expect(result[:attributes][:body]).to eq('Error message')
          expect(result[:attributes][:alert_type]).to eq('error')
          expect(result[:attributes][:veteran_status]).to eq('not confirmed')
          expect(result[:attributes][:not_confirmed_reason]).to eq('ERROR')
          expect(result[:attributes][:service_summary_code]).to eq(ssc_code)
        end
      end

      context 'with DISHONORABLE SSC codes' do
        let(:not_confirmed_reason) { 'MORE_RESEARCH_REQUIRED' }

        described_class::DISHONORABLE_SSC_CODES.each do |code|
          context "with SSC code #{code}" do
            let(:ssc_code) { code }

            it 'returns veteran_status_alert for dishonorable discharge' do
              result = subject.status_card

              expect(result[:type]).to eq('veteran_status_alert')
              expect(result[:attributes][:header]).to eq(VeteranStatusCard::Constants::DISHONORABLE_RESPONSE[:title])
              expect(result[:attributes][:body]).to eq(VeteranStatusCard::Constants::DISHONORABLE_RESPONSE[:message])
              expect(result[:attributes][:alert_type]).to eq(VeteranStatusCard::Constants::DISHONORABLE_RESPONSE[:status])
              expect(result[:attributes][:veteran_status]).to eq('not confirmed')
              expect(result[:attributes][:not_confirmed_reason]).to eq('MORE_RESEARCH_REQUIRED')
              expect(result[:attributes][:service_summary_code]).to eq(code)
            end
          end
        end
      end

      context 'with INELIGIBLE_SERVICE SSC codes' do
        let(:not_confirmed_reason) { 'MORE_RESEARCH_REQUIRED' }

        described_class::INELIGIBLE_SERVICE_SSC_CODES.each do |code|
          context "with SSC code #{code}" do
            let(:ssc_code) { code }

            it 'returns veteran_status_alert for ineligible service' do
              result = subject.status_card

              expect(result[:type]).to eq('veteran_status_alert')
              expect(result[:attributes][:header]).to eq(VeteranStatusCard::Constants::INELIGIBLE_SERVICE_RESPONSE[:title])
              expect(result[:attributes][:body]).to eq(VeteranStatusCard::Constants::INELIGIBLE_SERVICE_RESPONSE[:message])
              expect(result[:attributes][:alert_type]).to eq(VeteranStatusCard::Constants::INELIGIBLE_SERVICE_RESPONSE[:status])
              expect(result[:attributes][:veteran_status]).to eq('not confirmed')
              expect(result[:attributes][:not_confirmed_reason]).to eq('MORE_RESEARCH_REQUIRED')
              expect(result[:attributes][:service_summary_code]).to eq(code)
            end
          end
        end
      end

      context 'with UNKNOWN_SERVICE SSC code' do
        let(:not_confirmed_reason) { 'MORE_RESEARCH_REQUIRED' }
        let(:ssc_code) { 'U' }

        it 'returns veteran_status_alert for unknown service' do
          result = subject.status_card

          expect(result[:type]).to eq('veteran_status_alert')
          expect(result[:attributes][:header]).to eq(VeteranStatusCard::Constants::UNKNOWN_SERVICE_RESPONSE[:title])
          expect(result[:attributes][:body]).to eq(VeteranStatusCard::Constants::UNKNOWN_SERVICE_RESPONSE[:message])
          expect(result[:attributes][:alert_type]).to eq(VeteranStatusCard::Constants::UNKNOWN_SERVICE_RESPONSE[:status])
          expect(result[:attributes][:veteran_status]).to eq('not confirmed')
          expect(result[:attributes][:not_confirmed_reason]).to eq('MORE_RESEARCH_REQUIRED')
          expect(result[:attributes][:service_summary_code]).to eq('U')
        end
      end

      context 'with EDIPI_NO_PNL SSC code' do
        let(:not_confirmed_reason) { 'MORE_RESEARCH_REQUIRED' }
        let(:ssc_code) { 'X' }

        it 'returns veteran_status_alert for EDIPI no PNL' do
          result = subject.status_card

          expect(result[:type]).to eq('veteran_status_alert')
          expect(result[:attributes][:header]).to eq(VeteranStatusCard::Constants::EDIPI_NO_PNL_RESPONSE[:title])
          expect(result[:attributes][:body]).to eq(VeteranStatusCard::Constants::EDIPI_NO_PNL_RESPONSE[:message])
          expect(result[:attributes][:alert_type]).to eq(VeteranStatusCard::Constants::EDIPI_NO_PNL_RESPONSE[:status])
          expect(result[:attributes][:veteran_status]).to eq('not confirmed')
          expect(result[:attributes][:not_confirmed_reason]).to eq('MORE_RESEARCH_REQUIRED')
          expect(result[:attributes][:service_summary_code]).to eq('X')
        end
      end

      context 'with CURRENTLY_SERVING SSC codes' do
        let(:not_confirmed_reason) { 'MORE_RESEARCH_REQUIRED' }

        described_class::CURRENTLY_SERVING_CODES.each do |code|
          context "with SSC code #{code}" do
            let(:ssc_code) { code }

            it 'returns veteran_status_alert for currently serving' do
              result = subject.status_card

              expect(result[:type]).to eq('veteran_status_alert')
              expect(result[:attributes][:header]).to eq(VeteranStatusCard::Constants::CURRENTLY_SERVING_RESPONSE[:title])
              expect(result[:attributes][:body]).to eq(VeteranStatusCard::Constants::CURRENTLY_SERVING_RESPONSE[:message])
              expect(result[:attributes][:alert_type]).to eq(VeteranStatusCard::Constants::CURRENTLY_SERVING_RESPONSE[:status])
              expect(result[:attributes][:veteran_status]).to eq('not confirmed')
              expect(result[:attributes][:not_confirmed_reason]).to eq('MORE_RESEARCH_REQUIRED')
              expect(result[:attributes][:service_summary_code]).to eq(code)
            end
          end
        end
      end

      context 'with ERROR SSC codes' do
        let(:not_confirmed_reason) { 'MORE_RESEARCH_REQUIRED' }

        described_class::ERROR_SSC_CODES.each do |code|
          context "with SSC code #{code}" do
            let(:ssc_code) { code }

            it 'returns veteran_status_alert for SSC error code' do
              result = subject.status_card

              expect(result[:type]).to eq('veteran_status_alert')
              expect(result[:attributes][:header]).to eq(VeteranStatusCard::Constants::ERROR_RESPONSE[:title])
              expect(result[:attributes][:body]).to eq(VeteranStatusCard::Constants::ERROR_RESPONSE[:message])
              expect(result[:attributes][:alert_type]).to eq(VeteranStatusCard::Constants::ERROR_RESPONSE[:status])
              expect(result[:attributes][:veteran_status]).to eq('not confirmed')
              expect(result[:attributes][:not_confirmed_reason]).to eq('MORE_RESEARCH_REQUIRED')
              expect(result[:attributes][:service_summary_code]).to eq(code)
            end
          end
        end
      end
    end
  end

  describe '#eligible?' do
    context 'when vet_verification_eligible? returns true' do
      let(:veteran_status) { 'confirmed' }

      it 'returns true' do
        expect(subject.send(:eligible?)).to be true
      end
    end

    context 'when ssc_eligible? returns true' do
      let(:veteran_status) { 'not confirmed' }
      let(:not_confirmed_reason) { 'MORE_RESEARCH_REQUIRED' }
      let(:ssc_code) { 'A1' }

      it 'returns true' do
        expect(subject.send(:eligible?)).to be true
      end
    end

    context 'when neither condition is met' do
      let(:veteran_status) { 'not confirmed' }
      let(:not_confirmed_reason) { 'MORE_RESEARCH_REQUIRED' }
      let(:ssc_code) { 'U' }

      it 'returns false' do
        expect(subject.send(:eligible?)).to be false
      end
    end
  end

  describe '#vet_verification_eligible?' do
    context 'when veteran_status is confirmed' do
      let(:veteran_status) { 'confirmed' }

      it 'returns true' do
        expect(subject.send(:vet_verification_eligible?)).to be true
      end
    end

    context 'when veteran_status is not confirmed' do
      let(:veteran_status) { 'not confirmed' }

      it 'returns false' do
        expect(subject.send(:vet_verification_eligible?)).to be false
      end
    end
  end

  describe '#ssc_eligible?' do
    context 'when reason is MORE_RESEARCH_REQUIRED and SSC code is confirmed' do
      let(:veteran_status) { 'not confirmed' }
      let(:not_confirmed_reason) { 'MORE_RESEARCH_REQUIRED' }
      let(:ssc_code) { 'A1' }

      it 'returns true' do
        expect(subject.send(:ssc_eligible?)).to be true
      end
    end

    context 'when reason is NOT_TITLE_38 and SSC code is confirmed' do
      let(:veteran_status) { 'not confirmed' }
      let(:not_confirmed_reason) { 'NOT_TITLE_38' }
      let(:ssc_code) { 'B2' }

      it 'returns true' do
        expect(subject.send(:ssc_eligible?)).to be true
      end
    end

    context 'when reason is MORE_RESEARCH_REQUIRED but SSC code is not confirmed' do
      let(:veteran_status) { 'not confirmed' }
      let(:not_confirmed_reason) { 'MORE_RESEARCH_REQUIRED' }
      let(:ssc_code) { 'U' }

      it 'returns false' do
        expect(subject.send(:ssc_eligible?)).to be false
      end
    end

    context 'when reason is PERSON_NOT_FOUND' do
      let(:veteran_status) { 'not confirmed' }
      let(:not_confirmed_reason) { 'PERSON_NOT_FOUND' }
      let(:ssc_code) { 'A1' }

      it 'returns false' do
        expect(subject.send(:ssc_eligible?)).to be false
      end
    end
  end

  describe '#more_research_required_not_title_38?' do
    context 'when reason is MORE_RESEARCH_REQUIRED' do
      let(:not_confirmed_reason) { 'MORE_RESEARCH_REQUIRED' }

      it 'returns true' do
        expect(subject.send(:more_research_required_not_title_38?)).to be true
      end
    end

    context 'when reason is NOT_TITLE_38' do
      let(:not_confirmed_reason) { 'NOT_TITLE_38' }

      it 'returns true' do
        expect(subject.send(:more_research_required_not_title_38?)).to be true
      end
    end

    context 'when reason is PERSON_NOT_FOUND' do
      let(:not_confirmed_reason) { 'PERSON_NOT_FOUND' }

      it 'returns false' do
        expect(subject.send(:more_research_required_not_title_38?)).to be false
      end
    end

    context 'when reason is ERROR' do
      let(:not_confirmed_reason) { 'ERROR' }

      it 'returns false' do
        expect(subject.send(:more_research_required_not_title_38?)).to be false
      end
    end
  end

  describe '#disability_rating' do
    it 'returns disability rating from Lighthouse' do
      expect(lighthouse_disabilities_provider).to receive(:get_combined_disability_rating).and_return(70)

      expect(subject.send(:disability_rating)).to eq(70)
    end
  end

  describe '#dod_service_summary' do
    context 'with valid response' do
      it 'returns dod service summary data' do
        result = subject.send(:dod_service_summary)

        expect(result[:dod_service_summary_code]).to eq(ssc_code)
        expect(result[:calculation_model_version]).to eq('1.0')
        expect(result[:effective_start_date]).to eq('2020-01-01')
      end
    end

    context 'with nil dod_service_summary in response' do
      let(:dod_service_summary_model) { nil }

      it 'returns empty string values' do
        result = subject.send(:dod_service_summary)

        expect(result[:dod_service_summary_code]).to eq('')
        expect(result[:calculation_model_version]).to eq('')
        expect(result[:effective_start_date]).to eq('')
      end
    end
  end

  describe '#ssc_code' do
    context 'when dod_service_summary has a code' do
      let(:ssc_code) { 'B1' }

      it 'returns the code' do
        expect(subject.send(:ssc_code)).to eq('B1')
      end
    end

    context 'when dod_service_summary is nil' do
      let(:dod_service_summary_model) { nil }

      it 'returns empty string' do
        expect(subject.send(:ssc_code)).to eq('')
      end
    end
  end

  describe '#vet_verification_status' do
    it 'returns parsed vet verification data' do
      result = subject.send(:vet_verification_status)

      expect(result[:veteran_status]).to eq(veteran_status)
      expect(result[:reason]).to eq(not_confirmed_reason)
      expect(result[:message]).to eq(error_message)
      expect(result[:title]).to eq(error_title)
      expect(result[:status]).to eq(error_status)
    end
  end

  describe '#full_name' do
    it 'returns a formatted full name string' do
      allow(user).to receive(:full_name_normalized).and_return({
                                                                 first: 'John',
                                                                 middle: 'Michael',
                                                                 last: 'Doe',
                                                                 suffix: 'Jr'
                                                               })

      expect(subject.send(:full_name)).to eq('John Michael Doe Jr')
    end

    it 'capitalizes single-letter middle initials' do
      allow(user).to receive(:full_name_normalized).and_return({
                                                                 first: 'John',
                                                                 middle: 'a b',
                                                                 last: 'Doe',
                                                                 suffix: nil
                                                               })

      expect(subject.send(:full_name)).to eq('John A B Doe')
    end

    it 'handles mixed middle name with initials' do
      allow(user).to receive(:full_name_normalized).and_return({
                                                                 first: 'John',
                                                                 middle: 'a Michael b',
                                                                 last: 'Doe',
                                                                 suffix: nil
                                                               })

      expect(subject.send(:full_name)).to eq('John A Michael B Doe')
    end

    it 'handles missing middle name' do
      allow(user).to receive(:full_name_normalized).and_return({
                                                                 first: 'John',
                                                                 middle: nil,
                                                                 last: 'Doe',
                                                                 suffix: nil
                                                               })

      expect(subject.send(:full_name)).to eq('John Doe')
    end

    it 'handles missing suffix' do
      allow(user).to receive(:full_name_normalized).and_return({
                                                                 first: 'John',
                                                                 middle: 'Michael',
                                                                 last: 'Doe',
                                                                 suffix: nil
                                                               })

      expect(subject.send(:full_name)).to eq('John Michael Doe')
    end

    it 'handles empty strings' do
      allow(user).to receive(:full_name_normalized).and_return({
                                                                 first: 'John',
                                                                 middle: '',
                                                                 last: 'Doe',
                                                                 suffix: ''
                                                               })

      expect(subject.send(:full_name)).to eq('John Doe')
    end
  end

  describe 'memoization' do
    it 'memoizes vet_verification_status' do
      expect(vet_verification_service).to receive(:get_vet_verification_status).once

      2.times { subject.send(:vet_verification_status) }
    end

    it 'memoizes dod_service_summary' do
      expect(military_personnel_service).to receive(:get_dod_service_summary).once

      2.times { subject.send(:dod_service_summary) }
    end

    it 'memoizes ssc_code' do
      subject.send(:ssc_code)
      subject.send(:ssc_code)

      # ssc_code depends on dod_service_summary which should only be called once
      expect(military_personnel_service).to have_received(:get_dod_service_summary).once
    end
  end

  describe 'error scenarios' do
    describe 'service exceptions' do
      context 'when VeteranVerification::Service raises exception' do
        before do
          allow(vet_verification_service).to receive(:get_vet_verification_status)
            .and_raise(StandardError.new('Vet verification failed'))
        end

        it 'logs the error and returns error response' do
          expect(Rails.logger).to receive(:error).with(/VeteranVerification::Service error/, anything)

          result = subject.status_card

          expect(result[:type]).to eq('veteran_status_alert')
          expect(result[:attributes][:header]).to eq(VeteranStatusCard::Constants::ERROR_RESPONSE[:title])
          expect(result[:attributes][:body]).to eq(VeteranStatusCard::Constants::ERROR_RESPONSE[:message])
          expect(result[:attributes][:alert_type]).to eq(VeteranStatusCard::Constants::ERROR_RESPONSE[:status])
        end
      end

      context 'when VAProfile MilitaryPersonnel (DoD Summary) raises exception' do
        before do
          allow(military_personnel_service).to receive(:get_dod_service_summary)
            .and_raise(StandardError.new('DoD summary failed'))
        end

        it 'logs the error and returns empty SSC code' do
          expect(Rails.logger).to receive(:error).with(/VAProfile::MilitaryPersonnel \(DoD Summary\) error/, anything)

          ssc = subject.send(:ssc_code)

          expect(ssc).to eq('')
        end
      end

      context 'when disability rating provider raises exception' do
        let(:veteran_status) { 'confirmed' }

        before do
          allow(lighthouse_disabilities_provider).to receive(:get_combined_disability_rating)
            .and_raise(StandardError.new('Lighthouse failed'))
        end

        it 'logs the error and returns nil rating' do
          expect(Rails.logger).to receive(:error).with(/Disability rating error/, anything)

          result = subject.status_card

          expect(result[:type]).to eq('veteran_status_card')
          expect(result[:attributes][:disability_rating]).to be_nil
        end
      end

      context 'when top-level exception occurs' do
        let(:veteran_status) { 'confirmed' }

        before do
          allow(user).to receive(:full_name_normalized).and_raise(StandardError.new('Unexpected error'))
        end

        it 'logs the error and returns SOMETHING_WENT_WRONG_RESPONSE' do
          expect(Rails.logger).to receive(:error).with(/VeteranStatusCard::Service.*error/, anything)

          result = subject.status_card

          expect(result[:type]).to eq('veteran_status_alert')
          expect(result[:attributes][:header]).to eq(VeteranStatusCard::Constants::SOMETHING_WENT_WRONG_RESPONSE[:title])
          expect(result[:attributes][:body]).to eq(VeteranStatusCard::Constants::SOMETHING_WENT_WRONG_RESPONSE[:message])
          expect(result[:attributes][:alert_type]).to eq(VeteranStatusCard::Constants::SOMETHING_WENT_WRONG_RESPONSE[:status])
        end
      end
    end

    describe 'nil responses from services' do
      context 'when vet_verification_service returns nil' do
        before do
          allow(vet_verification_service).to receive(:get_vet_verification_status).and_return(nil)
        end

        it 'vet_verification_status handles nil gracefully' do
          status = subject.send(:vet_verification_status)

          expect(status[:veteran_status]).to be_nil
          expect(status[:reason]).to eq('ERROR')
          expect(status[:message]).to eq(VeteranStatusCard::Constants::ERROR_RESPONSE[:message])
          expect(status[:title]).to eq(VeteranStatusCard::Constants::ERROR_RESPONSE[:title])
          expect(status[:status]).to eq(VeteranStatusCard::Constants::ERROR_RESPONSE[:status])
        end
      end

      context 'when military_personnel_service.get_dod_service_summary returns nil' do
        before do
          allow(military_personnel_service).to receive(:get_dod_service_summary).and_return(nil)
        end

        it 'dod_service_summary returns empty strings' do
          summary = subject.send(:dod_service_summary)

          expect(summary[:dod_service_summary_code]).to eq('')
        end
      end

      context 'when disability rating returns nil' do
        let(:veteran_status) { 'confirmed' }

        before do
          allow(lighthouse_disabilities_provider).to receive(:get_combined_disability_rating).and_return(nil)
        end

        it 'disability_rating is nil' do
          result = subject.status_card

          expect(result[:attributes][:disability_rating]).to be_nil
        end
      end
    end

    describe 'malformed responses' do
      context 'when vet_verification_response missing data key' do
        before do
          allow(vet_verification_service).to receive(:get_vet_verification_status)
            .and_return({ 'error' => 'something went wrong' })
        end

        it 'handles missing keys gracefully with dig' do
          status = subject.send(:vet_verification_status)

          expect(status[:veteran_status]).to be_nil
          expect(status[:reason]).to be_nil
        end
      end

      context 'when dod_service_summary_response missing dod_service_summary' do
        let(:dod_service_summary_model) { nil }

        it 'returns empty strings for all fields' do
          summary = subject.send(:dod_service_summary)

          expect(summary[:dod_service_summary_code]).to eq('')
          expect(summary[:calculation_model_version]).to eq('')
          expect(summary[:effective_start_date]).to eq('')
        end
      end
    end

    describe 'error response formatting' do
      it 'error_response_hash formats Constants response correctly' do
        constants_response = {
          title: 'Test Title',
          message: ['Test Message'],
          status: 'error'
        }

        result = subject.send(:error_response_hash, constants_response)

        expect(result[:type]).to eq('veteran_status_alert')
        expect(result[:attributes][:header]).to eq('Test Title')
        expect(result[:attributes][:body]).to eq(['Test Message'])
        expect(result[:attributes][:alert_type]).to eq('error')
        expect(result[:attributes][:veteran_status]).to eq('not confirmed')
        expect(result[:attributes][:not_confirmed_reason]).to be_nil
        expect(result[:attributes][:confirmation_status]).to eq('NO_SSC_CHECK')
        expect(result[:attributes][:service_summary_code]).to eq(ssc_code)
      end
    end
  end
end
