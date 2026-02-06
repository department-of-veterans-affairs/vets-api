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

  let(:service_history_response) do
    instance_double(
      VAProfile::MilitaryPersonnel::ServiceHistoryResponse,
      episodes: service_episodes
    )
  end

  let(:service_episodes) do
    [
      VAProfile::Models::ServiceHistory.new(
        branch_of_service: 'Army',
        begin_date: '2010-01-01',
        end_date: '2015-12-31'
      )
    ]
  end

  let(:disability_rating) { 50 }

  before do
    allow(VeteranVerification::Service).to receive(:new).and_return(vet_verification_service)
    allow(vet_verification_service).to receive(:get_vet_verification_status).and_return(vet_verification_response)

    allow(VAProfile::MilitaryPersonnel::Service).to receive(:new).and_return(military_personnel_service)
    allow(military_personnel_service).to receive_messages(get_dod_service_summary: dod_service_summary_response,
                                                          get_service_history: service_history_response)

    allow(LighthouseRatedDisabilitiesProvider).to receive(:new).and_return(lighthouse_disabilities_provider)
    allow(lighthouse_disabilities_provider).to receive(:get_combined_disability_rating).and_return(disability_rating)
  end

  describe 'inheritance' do
    it 'inherits from VeteranStatusCard::Service' do
      expect(described_class.superclass).to eq(VeteranStatusCard::Service)
    end
  end

  describe 'protected method overrides' do
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

  describe '#status_card' do
    context 'when veteran is eligible' do
      let(:veteran_status) { 'confirmed' }

      it 'returns veteran_status_card with full veteran data' do
        result = subject.status_card

        expect(result[:type]).to eq('veteran_status_card')
        expect(result[:veteran_status]).to eq('confirmed')
        expect(result[:service_summary_code]).to eq(ssc_code)
        expect(result[:attributes][:full_name]).to be_a(String)
        expect(result[:attributes][:disability_rating]).to eq(50)
        expect(result[:attributes][:latest_service]).to be_present
        expect(result[:attributes][:edipi]).to eq(user.edipi)
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
          expect(result[:veteran_status]).to eq('not confirmed')
          expect(result[:attributes][:header]).to eq(Mobile::V0::VeteranStatusCard::Constants::DISHONORABLE_RESPONSE[:title])
          expect(result[:attributes][:body]).to eq(Mobile::V0::VeteranStatusCard::Constants::DISHONORABLE_RESPONSE[:message])
          expect(result[:attributes][:alert_type]).to eq(Mobile::V0::VeteranStatusCard::Constants::DISHONORABLE_RESPONSE[:status])
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
          expect(Rails.logger).to receive(:error).with(/VeteranStatusCard::Service error/, anything)

          result = subject.status_card

          expect(result[:type]).to eq('veteran_status_alert')
          expect(result[:veteran_status]).to eq('not confirmed')
          expect(result[:attributes][:header]).to eq(Mobile::V0::VeteranStatusCard::Constants::SOMETHING_WENT_WRONG_RESPONSE[:title])
          expect(result[:attributes][:body]).to eq(Mobile::V0::VeteranStatusCard::Constants::SOMETHING_WENT_WRONG_RESPONSE[:message])
          expect(result[:attributes][:alert_type]).to eq(Mobile::V0::VeteranStatusCard::Constants::SOMETHING_WENT_WRONG_RESPONSE[:status])
        end
      end
    end
  end
end
