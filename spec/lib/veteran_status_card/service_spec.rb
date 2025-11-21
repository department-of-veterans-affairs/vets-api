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
  let(:evss_service) { double('EVSS::CommonService') }

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
    allow(military_personnel_service).to receive(:get_dod_service_summary).and_return(dod_service_summary_response)
    allow(military_personnel_service).to receive(:get_service_history).and_return(service_history_response)

    allow(LighthouseRatedDisabilitiesProvider).to receive(:new).and_return(lighthouse_disabilities_provider)
    allow(lighthouse_disabilities_provider).to receive(:get_combined_disability_rating).and_return(disability_rating)

    allow(EVSS::CommonService).to receive(:new).and_return(evss_service)
    allow(evss_service).to receive(:get_rating_info).and_return(disability_rating)

    allow(Flipper).to receive(:enabled?).with(:profile_lighthouse_rating_info, user).and_return(true)
  end

  describe '#status_card' do
    context 'when veteran is eligible' do
      context 'via vet_verification_eligible? (confirmed status)' do
        let(:veteran_status) { 'confirmed' }

        it 'returns confirmed status with full veteran data' do
          result = subject.status_card

          expect(result[:confirmed]).to be true
          expect(result[:full_name]).to eq(user.full_name_normalized)
          expect(result[:user_percent_of_disability]).to eq(50)
          expect(result[:latest_service_history]).to be_present
          expect(result[:latest_service_history][:branch_of_service]).to eq('Army')
        end
      end

      context 'via ssc_eligibile? with MORE_RESEARCH_REQUIRED reason' do
        let(:veteran_status) { 'not confirmed' }
        let(:not_confirmed_reason) { 'MORE_RESEARCH_REQUIRED' }

        described_class::CONFIRMED_SSC_CODES.each do |code|
          context "with SSC code #{code}" do
            let(:ssc_code) { code }

            it 'returns confirmed status' do
              result = subject.status_card

              expect(result[:confirmed]).to be true
              expect(result[:full_name]).to eq(user.full_name_normalized)
            end
          end
        end
      end

      context 'via ssc_eligibile? with NOT_TITLE_38 reason' do
        let(:veteran_status) { 'not confirmed' }
        let(:not_confirmed_reason) { 'NOT_TITLE_38' }

        described_class::CONFIRMED_SSC_CODES.each do |code|
          context "with SSC code #{code}" do
            let(:ssc_code) { code }

            it 'returns confirmed status' do
              result = subject.status_card

              expect(result[:confirmed]).to be true
            end
          end
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

        it 'returns error details from vet verification status' do
          result = subject.status_card

          expect(result[:confirmed]).to be false
          expect(result[:title]).to eq('Person Not Found Title')
          expect(result[:message]).to eq('Person not found message')
          expect(result[:status]).to eq('error')
        end
      end

      context 'with ERROR reason' do
        let(:not_confirmed_reason) { 'ERROR' }
        let(:error_title) { 'Error Title' }
        let(:error_message) { 'Error message' }
        let(:error_status) { 'error' }

        it 'returns error details from vet verification status' do
          result = subject.status_card

          expect(result[:confirmed]).to be false
          expect(result[:title]).to eq('Error Title')
          expect(result[:message]).to eq('Error message')
          expect(result[:status]).to eq('error')
        end
      end

      context 'with MORE_RESEARCH_REQUIRED reason and TBD SSC codes' do
        let(:not_confirmed_reason) { 'MORE_RESEARCH_REQUIRED' }

        described_class::TBD_SSC_CODES.each do |code|
          context "with SSC code #{code}" do
            let(:ssc_code) { code }

            it 'returns error response with default messaging' do
              result = subject.status_card

              expect(result[:confirmed]).to be false
              expect(result[:title]).to eq(VeteranVerification::Constants::ERROR_MESSAGE_TITLE)
              expect(result[:message]).to eq(VeteranVerification::Constants::ERROR_MESSAGE)
              expect(result[:status]).to eq(VeteranVerification::Constants::ERROR_MESSAGE_STATUS)
            end
          end
        end
      end

      context 'with NOT_TITLE_38 reason and TBD SSC codes' do
        let(:not_confirmed_reason) { 'NOT_TITLE_38' }

        described_class::TBD_SSC_CODES.each do |code|
          context "with SSC code #{code}" do
            let(:ssc_code) { code }

            it 'returns error response with default messaging' do
              result = subject.status_card

              expect(result[:confirmed]).to be false
              expect(result[:title]).to eq(VeteranVerification::Constants::ERROR_MESSAGE_TITLE)
              expect(result[:message]).to eq(VeteranVerification::Constants::ERROR_MESSAGE)
              expect(result[:status]).to eq(VeteranVerification::Constants::ERROR_MESSAGE_STATUS)
            end
          end
        end
      end

      context 'with DISHONORABLE SSC codes' do
        let(:not_confirmed_reason) { 'MORE_RESEARCH_REQUIRED' }

        described_class::DISHONORABLE_SSC_CODES.each do |code|
          context "with SSC code #{code}" do
            let(:ssc_code) { code }

            it 'returns error response for dishonorable discharge' do
              result = subject.status_card

              expect(result[:confirmed]).to be false
              expect(result[:title]).to eq(VeteranVerification::Constants::ERROR_MESSAGE_TITLE)
              expect(result[:message]).to eq(VeteranVerification::Constants::ERROR_MESSAGE)
              expect(result[:status]).to eq(VeteranVerification::Constants::ERROR_MESSAGE_STATUS)
            end
          end
        end
      end

      context 'with UNKNOWN_SERVICE SSC code' do
        let(:not_confirmed_reason) { 'MORE_RESEARCH_REQUIRED' }
        let(:ssc_code) { 'U' }

        it 'returns error response for unknown service' do
          result = subject.status_card

          expect(result[:confirmed]).to be false
          expect(result[:title]).to eq(VeteranVerification::Constants::ERROR_MESSAGE_TITLE)
          expect(result[:message]).to eq(VeteranVerification::Constants::ERROR_MESSAGE)
          expect(result[:status]).to eq(VeteranVerification::Constants::ERROR_MESSAGE_STATUS)
        end
      end

      context 'with EDIPI_NO_PNL SSC code' do
        let(:not_confirmed_reason) { 'MORE_RESEARCH_REQUIRED' }
        let(:ssc_code) { 'X' }

        it 'returns error response for EDIPI no PNL' do
          result = subject.status_card

          expect(result[:confirmed]).to be false
          expect(result[:title]).to eq(VeteranVerification::Constants::ERROR_MESSAGE_TITLE)
          expect(result[:message]).to eq(VeteranVerification::Constants::ERROR_MESSAGE)
          expect(result[:status]).to eq(VeteranVerification::Constants::ERROR_MESSAGE_STATUS)
        end
      end

      context 'with CURRENTLY_SERVING SSC code' do
        let(:not_confirmed_reason) { 'MORE_RESEARCH_REQUIRED' }
        let(:ssc_code) { 'D^' }

        it 'returns error response for currently serving' do
          result = subject.status_card

          expect(result[:confirmed]).to be false
          expect(result[:title]).to eq(VeteranVerification::Constants::ERROR_MESSAGE_TITLE)
          expect(result[:message]).to eq(VeteranVerification::Constants::ERROR_MESSAGE)
          expect(result[:status]).to eq(VeteranVerification::Constants::ERROR_MESSAGE_STATUS)
        end
      end

      context 'with ERROR SSC codes' do
        let(:not_confirmed_reason) { 'MORE_RESEARCH_REQUIRED' }

        described_class::ERROR_SSC_CODES.each do |code|
          context "with SSC code #{code}" do
            let(:ssc_code) { code }

            it 'returns error response for SSC error code' do
              result = subject.status_card

              expect(result[:confirmed]).to be false
              expect(result[:title]).to eq(VeteranVerification::Constants::ERROR_MESSAGE_TITLE)
              expect(result[:message]).to eq(VeteranVerification::Constants::ERROR_MESSAGE)
              expect(result[:status]).to eq(VeteranVerification::Constants::ERROR_MESSAGE_STATUS)
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

    context 'when ssc_eligibile? returns true' do
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

  describe '#ssc_eligibile?' do
    context 'when reason is MORE_RESEARCH_REQUIRED and SSC code is confirmed' do
      let(:veteran_status) { 'not confirmed' }
      let(:not_confirmed_reason) { 'MORE_RESEARCH_REQUIRED' }
      let(:ssc_code) { 'A1' }

      it 'returns true' do
        expect(subject.send(:ssc_eligibile?)).to be true
      end
    end

    context 'when reason is NOT_TITLE_38 and SSC code is confirmed' do
      let(:veteran_status) { 'not confirmed' }
      let(:not_confirmed_reason) { 'NOT_TITLE_38' }
      let(:ssc_code) { 'B2' }

      it 'returns true' do
        expect(subject.send(:ssc_eligibile?)).to be true
      end
    end

    context 'when reason is MORE_RESEARCH_REQUIRED but SSC code is not confirmed' do
      let(:veteran_status) { 'not confirmed' }
      let(:not_confirmed_reason) { 'MORE_RESEARCH_REQUIRED' }
      let(:ssc_code) { 'U' }

      it 'returns false' do
        expect(subject.send(:ssc_eligibile?)).to be false
      end
    end

    context 'when reason is PERSON_NOT_FOUND' do
      let(:veteran_status) { 'not confirmed' }
      let(:not_confirmed_reason) { 'PERSON_NOT_FOUND' }
      let(:ssc_code) { 'A1' }

      it 'returns false' do
        expect(subject.send(:ssc_eligibile?)).to be false
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
    context 'when lighthouse is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:profile_lighthouse_rating_info, user).and_return(true)
      end

      it 'returns lighthouse rating' do
        expect(lighthouse_disabilities_provider).to receive(:get_combined_disability_rating).and_return(70)

        expect(subject.send(:disability_rating)).to eq(70)
      end
    end

    context 'when lighthouse is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:profile_lighthouse_rating_info, user).and_return(false)
      end

      it 'returns evss rating' do
        expect(evss_service).to receive(:get_rating_info).and_return(30)

        expect(subject.send(:disability_rating)).to eq(30)
      end
    end
  end

  describe '#latest_service_history' do
    context 'with service episodes' do
      let(:service_episodes) do
        [
          VAProfile::Models::ServiceHistory.new(
            branch_of_service: 'Navy',
            begin_date: '2000-01-01',
            end_date: '2005-12-31'
          ),
          VAProfile::Models::ServiceHistory.new(
            branch_of_service: 'Army',
            begin_date: '2010-01-01',
            end_date: '2015-12-31'
          )
        ]
      end

      it 'returns the most recent service episode' do
        result = subject.send(:latest_service_history)

        expect(result[:branch_of_service]).to eq('Army')
        expect(result[:latest_service_date_range][:begin_date]).to eq('2010-01-01')
        expect(result[:latest_service_date_range][:end_date]).to eq('2015-12-31')
      end
    end

    context 'with no service episodes' do
      let(:service_episodes) { [] }

      it 'returns nil values' do
        result = subject.send(:latest_service_history)

        expect(result[:branch_of_service]).to be_nil
        expect(result[:latest_service_date_range]).to be_nil
      end
    end
  end

  describe '#format_service_date_range' do
    context 'with a service episode' do
      let(:episode) do
        VAProfile::Models::ServiceHistory.new(
          begin_date: '2010-01-01',
          end_date: '2015-12-31'
        )
      end

      it 'returns formatted date range' do
        result = subject.send(:format_service_date_range, episode)

        expect(result[:begin_date]).to eq('2010-01-01')
        expect(result[:end_date]).to eq('2015-12-31')
      end
    end

    context 'with nil episode' do
      it 'returns nil' do
        result = subject.send(:format_service_date_range, nil)

        expect(result).to be_nil
      end
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
    it 'returns the user full_name_normalized' do
      expect(subject.send(:full_name)).to eq(user.full_name_normalized)
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
end
