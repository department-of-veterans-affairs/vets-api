# frozen_string_literal: true

require_relative '../../../../support/helpers/rails_helper'
require 'mobile/v0/veteran_status_card/service'

RSpec.describe Mobile::V0::VeteranStatusCard::Service do
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

  describe 'inheritance' do
    it 'inherits from VeteranStatusCard::Service' do
      expect(described_class.superclass).to eq(VeteranStatusCard::Service)
    end
  end

  describe 'protected method overrides' do
    describe '#statsd_key_prefix' do
      it 'returns Mobile-specific prefix' do
        expect(subject.send(:statsd_key_prefix)).to eq('veteran_status_card.mobile')
      end
    end

    describe '#service_name' do
      it 'returns Mobile-specific service name' do
        expect(subject.send(:service_name)).to eq('[Mobile::V0::VeteranStatusCard::Service]')
      end
    end

    describe '#something_went_wrong_response' do
      it 'returns Mobile constants' do
        expect(subject.send(:something_went_wrong_response)).to eq(
          Mobile::V0::VeteranStatusCard::Constants::SOMETHING_WENT_WRONG_RESPONSE
        )
      end
    end

    describe '#dishonorable_response' do
      it 'returns Mobile constants' do
        expect(subject.send(:dishonorable_response)).to eq(
          Mobile::V0::VeteranStatusCard::Constants::DISHONORABLE_RESPONSE
        )
      end
    end

    describe '#ineligible_service_response' do
      it 'returns Mobile constants' do
        expect(subject.send(:ineligible_service_response)).to eq(
          Mobile::V0::VeteranStatusCard::Constants::INELIGIBLE_SERVICE_RESPONSE
        )
      end
    end

    describe '#unknown_service_response' do
      it 'returns Mobile constants' do
        expect(subject.send(:unknown_service_response)).to eq(
          Mobile::V0::VeteranStatusCard::Constants::UNKNOWN_SERVICE_RESPONSE
        )
      end
    end

    describe '#edipi_no_pnl_response' do
      it 'returns Mobile constants' do
        expect(subject.send(:edipi_no_pnl_response)).to eq(
          Mobile::V0::VeteranStatusCard::Constants::EDIPI_NO_PNL_RESPONSE
        )
      end
    end

    describe '#currently_serving_response' do
      it 'returns Mobile constants' do
        expect(subject.send(:currently_serving_response)).to eq(
          Mobile::V0::VeteranStatusCard::Constants::CURRENTLY_SERVING_RESPONSE
        )
      end
    end

    describe '#error_response' do
      it 'returns Mobile constants' do
        expect(subject.send(:error_response)).to eq(
          Mobile::V0::VeteranStatusCard::Constants::ERROR_RESPONSE
        )
      end
    end
  end

  describe '#initialize' do
    before do
      allow(StatsD).to receive(:increment)
    end

    context 'when user is valid' do
      it 'logs STATSD_TOTAL with mobile prefix' do
        described_class.new(user)

        expect(StatsD).to have_received(:increment).with('veteran_status_card.mobile.total')
      end

      it 'does not log STATSD_FAILURE' do
        described_class.new(user)

        expect(StatsD).not_to have_received(:increment).with('veteran_status_card.mobile.failure')
      end
    end

    context 'when user is nil' do
      it 'logs STATSD_TOTAL and STATSD_FAILURE with mobile prefix' do
        expect { described_class.new(nil) }.to raise_error(ArgumentError)

        expect(StatsD).to have_received(:increment).with('veteran_status_card.mobile.total')
        expect(StatsD).to have_received(:increment).with('veteran_status_card.mobile.failure')
      end
    end

    context 'when user edipi and icn are nil' do
      before do
        allow(user).to receive_messages(edipi: nil, icn: nil)
      end

      it 'logs STATSD_TOTAL and STATSD_FAILURE with mobile prefix' do
        expect { described_class.new(user) }.to raise_error(ArgumentError)

        expect(StatsD).to have_received(:increment).with('veteran_status_card.mobile.total')
        expect(StatsD).to have_received(:increment).with('veteran_status_card.mobile.failure')
      end
    end
  end

  describe '#status_card' do
    describe 'StatsD logging with mobile prefix' do
      before do
        allow(StatsD).to receive(:increment)
        allow(Rails.logger).to receive(:info)
        allow(Rails.logger).to receive(:error)
      end

      context 'when veteran is eligible' do
        let(:veteran_status) { 'confirmed' }

        it 'logs STATSD_ELIGIBLE with mobile prefix' do
          subject.status_card

          expect(StatsD).to have_received(:increment).with('veteran_status_card.mobile.eligible')
        end

        it 'logs VSC Card Result info with mobile service name' do
          subject.status_card

          expect(Rails.logger).to have_received(:info).with(
            '[Mobile::V0::VeteranStatusCard::Service] VSC Card Result',
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

        it 'logs STATSD_INELIGIBLE with mobile prefix' do
          subject.status_card

          expect(StatsD).to have_received(:increment).with('veteran_status_card.mobile.ineligible')
        end

        it 'logs VSC Card Result info with mobile service name' do
          subject.status_card

          expect(Rails.logger).to have_received(:info).with(
            '[Mobile::V0::VeteranStatusCard::Service] VSC Card Result',
            hash_including(
              veteran_status: 'not confirmed',
              not_confirmed_reason: 'PERSON_NOT_FOUND',
              service_summary_code: ssc_code
            )
          )
        end
      end

      context 'when an exception occurs' do
        let(:veteran_status) { 'confirmed' }

        before do
          allow(user).to receive(:full_name_normalized).and_raise(StandardError.new('Test error'))
        end

        it 'logs STATSD_FAILURE with mobile prefix' do
          subject.status_card

          expect(StatsD).to have_received(:increment).with('veteran_status_card.mobile.failure')
        end

        it 'logs error with mobile service name' do
          subject.status_card

          expect(Rails.logger).to have_received(:error).with(
            '[Mobile::V0::VeteranStatusCard::Service] error: Test error',
            hash_including(:backtrace)
          )
        end
      end

      describe 'ineligibility reason StatsD logging with mobile prefix' do
        context 'with DISHONORABLE SSC code' do
          let(:veteran_status) { 'not confirmed' }
          let(:not_confirmed_reason) { 'MORE_RESEARCH_REQUIRED' }
          let(:ssc_code) { 'A5' }

          it 'logs DISHONORABLE_SSC_MESSAGE with mobile prefix' do
            subject.status_card

            expect(StatsD).to have_received(:increment).with('veteran_status_card.mobile.dishonorable_ssc')
          end
        end

        context 'with INELIGIBLE_SERVICE SSC code' do
          let(:veteran_status) { 'not confirmed' }
          let(:not_confirmed_reason) { 'MORE_RESEARCH_REQUIRED' }
          let(:ssc_code) { 'G2' }

          it 'logs INELIGIBLE_SSC_MESSAGE with mobile prefix' do
            subject.status_card

            expect(StatsD).to have_received(:increment).with('veteran_status_card.mobile.ineligible_ssc')
          end
        end

        context 'with UNKNOWN_SERVICE SSC code' do
          let(:veteran_status) { 'not confirmed' }
          let(:not_confirmed_reason) { 'MORE_RESEARCH_REQUIRED' }
          let(:ssc_code) { 'U' }

          it 'logs UNKNOWN_SSC_MESSAGE with mobile prefix' do
            subject.status_card

            expect(StatsD).to have_received(:increment).with('veteran_status_card.mobile.unknown_ssc')
          end
        end

        context 'with EDIPI_NO_PNL SSC code' do
          let(:veteran_status) { 'not confirmed' }
          let(:not_confirmed_reason) { 'MORE_RESEARCH_REQUIRED' }
          let(:ssc_code) { 'X' }

          it 'logs EDIPI_NO_PNL_SSC_MESSAGE with mobile prefix' do
            subject.status_card

            expect(StatsD).to have_received(:increment).with('veteran_status_card.mobile.edipi_no_pnl_ssc')
          end
        end

        context 'with CURRENTLY_SERVING SSC code' do
          let(:veteran_status) { 'not confirmed' }
          let(:not_confirmed_reason) { 'MORE_RESEARCH_REQUIRED' }
          let(:ssc_code) { 'D' }

          it 'logs CURRENTLY_SERVING_SSC_MESSAGE with mobile prefix' do
            subject.status_card

            expect(StatsD).to have_received(:increment).with('veteran_status_card.mobile.currently_serving_ssc')
          end
        end

        context 'with ERROR SSC code' do
          let(:veteran_status) { 'not confirmed' }
          let(:not_confirmed_reason) { 'MORE_RESEARCH_REQUIRED' }
          let(:ssc_code) { 'VNA' }

          it 'logs ERROR_SSC_MESSAGE with mobile prefix' do
            subject.status_card

            expect(StatsD).to have_received(:increment).with('veteran_status_card.mobile.error_ssc')
          end
        end

        context 'with uncaught SSC code' do
          let(:veteran_status) { 'not confirmed' }
          let(:not_confirmed_reason) { 'MORE_RESEARCH_REQUIRED' }
          let(:ssc_code) { 'UNKNOWN_CODE' }

          it 'logs UNCAUGHT_SSC_MESSAGE with mobile prefix' do
            subject.status_card

            expect(StatsD).to have_received(:increment).with('veteran_status_card.mobile.uncaught_ssc')
          end
        end

        context 'with PERSON_NOT_FOUND reason' do
          let(:veteran_status) { 'not confirmed' }
          let(:not_confirmed_reason) { 'PERSON_NOT_FOUND' }

          it 'logs the vet_verification_status reason with mobile prefix' do
            subject.status_card

            expect(StatsD).to have_received(:increment).with('veteran_status_card.mobile.person_not_found')
          end
        end

        context 'with ERROR reason' do
          let(:veteran_status) { 'not confirmed' }
          let(:not_confirmed_reason) { 'ERROR' }
          let(:error_title) { 'Error' }
          let(:error_message) { 'An error occurred' }
          let(:error_status) { 'error' }

          it 'logs the vet_verification_status reason with mobile prefix' do
            subject.status_card

            expect(StatsD).to have_received(:increment).with('veteran_status_card.mobile.error')
          end
        end
      end
    end

    context 'when veteran is eligible' do
      let(:veteran_status) { 'confirmed' }

      it 'returns veteran_status_card with full veteran data' do
        result = subject.status_card

        expect(result[:type]).to eq('veteran_status_card')
        expect(result[:attributes][:full_name]).to be_a(String)
        expect(result[:attributes][:disability_rating]).to eq(50)
        expect(result[:attributes][:edipi]).to eq(user.edipi)
        expect(result[:attributes][:veteran_status]).to eq('confirmed')
        expect(result[:attributes][:not_confirmed_reason]).to be_nil
        expect(result[:attributes][:service_summary_code]).to eq(ssc_code)
      end
    end

    context 'when veteran is not eligible' do
      let(:veteran_status) { 'not confirmed' }

      context 'with DISHONORABLE SSC codes' do
        let(:not_confirmed_reason) { 'MORE_RESEARCH_REQUIRED' }
        let(:ssc_code) { 'A5' }

        it 'returns veteran_status_alert with Mobile dishonorable constants' do
          result = subject.status_card

          expect(result[:type]).to eq('veteran_status_alert')
          expect(result[:attributes][:header]).to eq(Mobile::V0::VeteranStatusCard::Constants::DISHONORABLE_RESPONSE[:title])
          expect(result[:attributes][:body]).to eq(Mobile::V0::VeteranStatusCard::Constants::DISHONORABLE_RESPONSE[:message])
          expect(result[:attributes][:alert_type]).to eq(Mobile::V0::VeteranStatusCard::Constants::DISHONORABLE_RESPONSE[:status])
          expect(result[:attributes][:veteran_status]).to eq('not confirmed')
          expect(result[:attributes][:not_confirmed_reason]).to eq('MORE_RESEARCH_REQUIRED')
          expect(result[:attributes][:service_summary_code]).to eq(ssc_code)
        end
      end

      context 'with INELIGIBLE_SERVICE SSC codes' do
        let(:not_confirmed_reason) { 'MORE_RESEARCH_REQUIRED' }
        let(:ssc_code) { 'G2' }

        it 'returns veteran_status_alert with Mobile ineligible service constants' do
          result = subject.status_card

          expect(result[:type]).to eq('veteran_status_alert')
          expect(result[:attributes][:header]).to eq(Mobile::V0::VeteranStatusCard::Constants::INELIGIBLE_SERVICE_RESPONSE[:title])
          expect(result[:attributes][:body]).to eq(Mobile::V0::VeteranStatusCard::Constants::INELIGIBLE_SERVICE_RESPONSE[:message])
          expect(result[:attributes][:alert_type]).to eq(Mobile::V0::VeteranStatusCard::Constants::INELIGIBLE_SERVICE_RESPONSE[:status])
        end
      end

      context 'with UNKNOWN_SERVICE SSC code' do
        let(:not_confirmed_reason) { 'MORE_RESEARCH_REQUIRED' }
        let(:ssc_code) { 'U' }

        it 'returns veteran_status_alert with Mobile unknown service constants' do
          result = subject.status_card

          expect(result[:type]).to eq('veteran_status_alert')
          expect(result[:attributes][:header]).to eq(Mobile::V0::VeteranStatusCard::Constants::UNKNOWN_SERVICE_RESPONSE[:title])
          expect(result[:attributes][:body]).to eq(Mobile::V0::VeteranStatusCard::Constants::UNKNOWN_SERVICE_RESPONSE[:message])
          expect(result[:attributes][:alert_type]).to eq(Mobile::V0::VeteranStatusCard::Constants::UNKNOWN_SERVICE_RESPONSE[:status])
        end
      end

      context 'with EDIPI_NO_PNL SSC code' do
        let(:not_confirmed_reason) { 'MORE_RESEARCH_REQUIRED' }
        let(:ssc_code) { 'X' }

        it 'returns veteran_status_alert with Mobile EDIPI no PNL constants' do
          result = subject.status_card

          expect(result[:type]).to eq('veteran_status_alert')
          expect(result[:attributes][:header]).to eq(Mobile::V0::VeteranStatusCard::Constants::EDIPI_NO_PNL_RESPONSE[:title])
          expect(result[:attributes][:body]).to eq(Mobile::V0::VeteranStatusCard::Constants::EDIPI_NO_PNL_RESPONSE[:message])
          expect(result[:attributes][:alert_type]).to eq(Mobile::V0::VeteranStatusCard::Constants::EDIPI_NO_PNL_RESPONSE[:status])
        end
      end

      context 'with CURRENTLY_SERVING SSC codes' do
        let(:not_confirmed_reason) { 'MORE_RESEARCH_REQUIRED' }
        let(:ssc_code) { 'D' }

        it 'returns veteran_status_alert with Mobile currently serving constants' do
          result = subject.status_card

          expect(result[:type]).to eq('veteran_status_alert')
          expect(result[:attributes][:header]).to eq(Mobile::V0::VeteranStatusCard::Constants::CURRENTLY_SERVING_RESPONSE[:title])
          expect(result[:attributes][:body]).to eq(Mobile::V0::VeteranStatusCard::Constants::CURRENTLY_SERVING_RESPONSE[:message])
          expect(result[:attributes][:alert_type]).to eq(Mobile::V0::VeteranStatusCard::Constants::CURRENTLY_SERVING_RESPONSE[:status])
        end
      end

      context 'with ERROR SSC codes' do
        let(:not_confirmed_reason) { 'MORE_RESEARCH_REQUIRED' }
        let(:ssc_code) { 'VNA' }

        it 'returns veteran_status_alert with Mobile error constants' do
          result = subject.status_card

          expect(result[:type]).to eq('veteran_status_alert')
          expect(result[:attributes][:header]).to eq(Mobile::V0::VeteranStatusCard::Constants::ERROR_RESPONSE[:title])
          expect(result[:attributes][:body]).to eq(Mobile::V0::VeteranStatusCard::Constants::ERROR_RESPONSE[:message])
          expect(result[:attributes][:alert_type]).to eq(Mobile::V0::VeteranStatusCard::Constants::ERROR_RESPONSE[:status])
        end
      end
    end

    context 'error scenarios' do
      context 'when user is nil' do
        it 'raises ArgumentError (inherited from base class)' do
          expect { described_class.new(nil) }.to raise_error(ArgumentError, 'User cannot be nil')
        end
      end

      context 'when top-level exception occurs' do
        let(:veteran_status) { 'confirmed' }

        before do
          allow(user).to receive(:full_name_normalized).and_raise(StandardError.new('Unexpected error'))
        end

        it 'logs the error and returns Mobile SOMETHING_WENT_WRONG_RESPONSE' do
          expect(Rails.logger).to receive(:error).with(/Mobile::V0::VeteranStatusCard::Service.*error/, anything)

          result = subject.status_card

          expect(result[:type]).to eq('veteran_status_alert')
          expect(result[:attributes][:header]).to eq(Mobile::V0::VeteranStatusCard::Constants::SOMETHING_WENT_WRONG_RESPONSE[:title])
          expect(result[:attributes][:body]).to eq(Mobile::V0::VeteranStatusCard::Constants::SOMETHING_WENT_WRONG_RESPONSE[:message])
          expect(result[:attributes][:alert_type]).to eq(Mobile::V0::VeteranStatusCard::Constants::SOMETHING_WENT_WRONG_RESPONSE[:status])
        end
      end
    end
  end
end
