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

  describe '#initialize' do
    context 'when user is not nil' do
      context 'when user edipi and icn are nil' do
        before do
          allow(user).to receive_messages(edipi: nil, icn: nil)
        end

        it 'raises an argument error' do
          expect { VeteranStatusCard::Service.new(user) }.to raise_error(ArgumentError)
        end
      end

      context 'when user edipi or icn are not nil' do
        it 'does not raise an argument error' do
          expect { VeteranStatusCard::Service.new(user) }.not_to raise_error(ArgumentError)
        end
      end
    end

    context 'when user is nil' do
      it 'raises an argument error' do
        expect { VeteranStatusCard::Service.new(nil) }.to raise_error(ArgumentError)
      end
    end
  end

  describe '#status_card' do
    context 'when veteran is eligible' do
      context 'via vet_verification_eligible? (confirmed status)' do
        let(:veteran_status) { 'confirmed' }

        it 'returns veteran_status_card with full veteran data' do
          result = subject.status_card

          expect(result[:type]).to eq('veteran_status_card')
          expect(result[:veteran_status]).to eq('confirmed')
          expect(result[:service_summary_code]).to eq(ssc_code)
          expect(result[:not_confirmed_reason]).to be_nil

          expect(result[:attributes][:full_name]).to be_a(String)
          expect(result[:attributes][:full_name]).to be_present
          expect(result[:attributes][:disability_rating]).to eq(50)
          expect(result[:attributes][:latest_service]).to be_present
          expect(result[:attributes][:latest_service][:branch]).to eq('Army')
          expect(result[:attributes][:edipi]).to eq(user.edipi)
        end
      end

      context 'via ssc_eligible? with MORE_RESEARCH_REQUIRED reason' do
        let(:veteran_status) { 'not confirmed' }
        let(:not_confirmed_reason) { 'MORE_RESEARCH_REQUIRED' }

        described_class::CONFIRMED_SSC_CODES.each do |code|
          context "with SSC code #{code}" do
            let(:ssc_code) { code }

            it 'returns veteran_status_card for confirmed SSC code' do
              result = subject.status_card

              expect(result[:type]).to eq('veteran_status_card')
              expect(result[:veteran_status]).to eq('confirmed')
              expect(result[:service_summary_code]).to eq(code)
              expect(result[:not_confirmed_reason]).to eq('MORE_RESEARCH_REQUIRED')

              expect(result[:attributes][:full_name]).to be_a(String)
              expect(result[:attributes][:full_name]).to be_present
            end
          end
        end
      end

      context 'via ssc_eligible? with NOT_TITLE_38 reason' do
        let(:veteran_status) { 'not confirmed' }
        let(:not_confirmed_reason) { 'NOT_TITLE_38' }

        described_class::CONFIRMED_SSC_CODES.each do |code|
          context "with SSC code #{code}" do
            let(:ssc_code) { code }

            it 'returns veteran_status_card for confirmed SSC code' do
              result = subject.status_card

              expect(result[:type]).to eq('veteran_status_card')
              expect(result[:veteran_status]).to eq('confirmed')
              expect(result[:service_summary_code]).to eq(code)
              expect(result[:not_confirmed_reason]).to eq('NOT_TITLE_38')
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

      context 'service history scenarios' do
        let(:veteran_status) { 'confirmed' }

        it 'returns complete service history with date range' do
          result = subject.status_card

          expect(result[:type]).to eq('veteran_status_card')
          expect(result[:attributes][:latest_service]).to be_present
          expect(result[:attributes][:latest_service][:branch]).to eq('Army')
          expect(result[:attributes][:latest_service][:begin_date]).to eq('2010-01-01')
          expect(result[:attributes][:latest_service][:end_date]).to eq('2015-12-31')
        end

        context 'with multiple service episodes' do
          let(:service_episodes) do
            [
              VAProfile::Models::ServiceHistory.new(
                branch_of_service: 'Army',
                begin_date: '2000-01-01',
                end_date: '2005-12-31'
              ),
              VAProfile::Models::ServiceHistory.new(
                branch_of_service: 'Navy',
                begin_date: '2010-01-01',
                end_date: '2015-12-31'
              ),
              VAProfile::Models::ServiceHistory.new(
                branch_of_service: 'Air Force',
                begin_date: '2018-01-01',
                end_date: '2023-12-31'
              )
            ]
          end

          it 'returns the most recent service episode' do
            result = subject.status_card

            expect(result[:type]).to eq('veteran_status_card')
            expect(result[:attributes][:latest_service][:branch]).to eq('Air Force')
            expect(result[:attributes][:latest_service][:begin_date]).to eq('2018-01-01')
            expect(result[:attributes][:latest_service][:end_date]).to eq('2023-12-31')
          end
        end

        context 'with empty episodes array' do
          let(:service_episodes) { [] }

          it 'returns UNKNOWN_SERVICE_RESPONSE alert' do
            result = subject.status_card

            expect(result[:type]).to eq('veteran_status_alert')
            expect(result[:veteran_status]).to eq('not confirmed')
            expect(result[:attributes][:header]).to eq(VeteranStatusCard::Constants::UNKNOWN_SERVICE_RESPONSE[:title])
            expect(result[:attributes][:body]).to eq(VeteranStatusCard::Constants::UNKNOWN_SERVICE_RESPONSE[:message])
            expect(result[:attributes][:alert_type]).to eq(VeteranStatusCard::Constants::UNKNOWN_SERVICE_RESPONSE[:status])
          end
        end
      end

      context 'complete data structure validation' do
        let(:veteran_status) { 'confirmed' }

        it 'returns all expected fields with correct types' do
          result = subject.status_card

          expect(result).to be_a(Hash)
          expect(result.keys).to contain_exactly(:type, :veteran_status,
                                                 :service_summary_code, :not_confirmed_reason, :attributes)

          expect(result[:type]).to eq('veteran_status_card')
          expect(result[:veteran_status]).to eq('confirmed')
          expect(result[:service_summary_code]).to eq(ssc_code)

          expect(result[:attributes]).to be_a(Hash)
          expect(result[:attributes].keys).to contain_exactly(:full_name, :disability_rating,
                                                              :latest_service, :edipi)
          expect(result[:attributes][:full_name]).to be_a(String)
          expect(result[:attributes][:disability_rating]).to be_a(Integer)
          expect(result[:attributes][:edipi]).to eq(user.edipi)

          expect(result[:attributes][:latest_service]).to be_a(Hash)
          expect(result[:attributes][:latest_service].keys).to contain_exactly(:branch, :begin_date, :end_date)
          expect(result[:attributes][:latest_service][:branch]).to be_a(String)
          expect(result[:attributes][:latest_service][:begin_date]).to be_a(String)
          expect(result[:attributes][:latest_service][:end_date]).to be_a(String)
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
          expect(result[:veteran_status]).to eq('not confirmed')
          expect(result[:service_summary_code]).to eq(ssc_code)
          expect(result[:not_confirmed_reason]).to eq('PERSON_NOT_FOUND')

          expect(result[:attributes][:header]).to eq('Person Not Found Title')
          expect(result[:attributes][:body]).to eq('Person not found message')
          expect(result[:attributes][:alert_type]).to eq('error')
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
          expect(result[:veteran_status]).to eq('not confirmed')
          expect(result[:service_summary_code]).to eq(ssc_code)
          expect(result[:not_confirmed_reason]).to eq('ERROR')

          expect(result[:attributes][:header]).to eq('Error Title')
          expect(result[:attributes][:body]).to eq('Error message')
          expect(result[:attributes][:alert_type]).to eq('error')
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
              expect(result[:veteran_status]).to eq('not confirmed')
              expect(result[:service_summary_code]).to eq(code)
              expect(result[:not_confirmed_reason]).to eq('MORE_RESEARCH_REQUIRED')

              expect(result[:attributes][:header]).to eq(VeteranStatusCard::Constants::DISHONORABLE_RESPONSE[:title])
              expect(result[:attributes][:body]).to eq(VeteranStatusCard::Constants::DISHONORABLE_RESPONSE[:message])
              expect(result[:attributes][:alert_type]).to eq(VeteranStatusCard::Constants::DISHONORABLE_RESPONSE[:status])
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
              expect(result[:veteran_status]).to eq('not confirmed')
              expect(result[:service_summary_code]).to eq(code)
              expect(result[:not_confirmed_reason]).to eq('MORE_RESEARCH_REQUIRED')

              expect(result[:attributes][:header]).to eq(VeteranStatusCard::Constants::INELIGIBLE_SERVICE_RESPONSE[:title])
              expect(result[:attributes][:body]).to eq(VeteranStatusCard::Constants::INELIGIBLE_SERVICE_RESPONSE[:message])
              expect(result[:attributes][:alert_type]).to eq(VeteranStatusCard::Constants::INELIGIBLE_SERVICE_RESPONSE[:status])
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
          expect(result[:veteran_status]).to eq('not confirmed')
          expect(result[:service_summary_code]).to eq('U')
          expect(result[:not_confirmed_reason]).to eq('MORE_RESEARCH_REQUIRED')

          expect(result[:attributes][:header]).to eq(VeteranStatusCard::Constants::UNKNOWN_SERVICE_RESPONSE[:title])
          expect(result[:attributes][:body]).to eq(VeteranStatusCard::Constants::UNKNOWN_SERVICE_RESPONSE[:message])
          expect(result[:attributes][:alert_type]).to eq(VeteranStatusCard::Constants::UNKNOWN_SERVICE_RESPONSE[:status])
        end
      end

      context 'with EDIPI_NO_PNL SSC code' do
        let(:not_confirmed_reason) { 'MORE_RESEARCH_REQUIRED' }
        let(:ssc_code) { 'X' }

        it 'returns veteran_status_alert for EDIPI no PNL' do
          result = subject.status_card

          expect(result[:type]).to eq('veteran_status_alert')
          expect(result[:veteran_status]).to eq('not confirmed')
          expect(result[:service_summary_code]).to eq('X')
          expect(result[:not_confirmed_reason]).to eq('MORE_RESEARCH_REQUIRED')

          expect(result[:attributes][:header]).to eq(VeteranStatusCard::Constants::EDIPI_NO_PNL_RESPONSE[:title])
          expect(result[:attributes][:body]).to eq(VeteranStatusCard::Constants::EDIPI_NO_PNL_RESPONSE[:message])
          expect(result[:attributes][:alert_type]).to eq(VeteranStatusCard::Constants::EDIPI_NO_PNL_RESPONSE[:status])
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
              expect(result[:veteran_status]).to eq('not confirmed')
              expect(result[:service_summary_code]).to eq(code)
              expect(result[:not_confirmed_reason]).to eq('MORE_RESEARCH_REQUIRED')

              expect(result[:attributes][:header]).to eq(VeteranStatusCard::Constants::CURRENTLY_SERVING_RESPONSE[:title])
              expect(result[:attributes][:body]).to eq(VeteranStatusCard::Constants::CURRENTLY_SERVING_RESPONSE[:message])
              expect(result[:attributes][:alert_type]).to eq(VeteranStatusCard::Constants::CURRENTLY_SERVING_RESPONSE[:status])
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
              expect(result[:veteran_status]).to eq('not confirmed')
              expect(result[:service_summary_code]).to eq(code)
              expect(result[:not_confirmed_reason]).to eq('MORE_RESEARCH_REQUIRED')

              expect(result[:attributes][:header]).to eq(VeteranStatusCard::Constants::ERROR_RESPONSE[:title])
              expect(result[:attributes][:body]).to eq(VeteranStatusCard::Constants::ERROR_RESPONSE[:message])
              expect(result[:attributes][:alert_type]).to eq(VeteranStatusCard::Constants::ERROR_RESPONSE[:status])
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

        expect(result[:branch]).to eq('Army')
        expect(result[:begin_date]).to eq('2010-01-01')
        expect(result[:end_date]).to eq('2015-12-31')
      end
    end

    context 'with no service episodes' do
      let(:service_episodes) { [] }

      it 'returns nil values' do
        result = subject.send(:latest_service_history)

        expect(result[:branch]).to be_nil
        expect(result[:begin_date]).to be_nil
        expect(result[:end_date]).to be_nil
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
          expect(result[:veteran_status]).to eq('not confirmed')
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

      context 'when VAProfile MilitaryPersonnel (Service History) raises exception' do
        let(:veteran_status) { 'confirmed' }

        before do
          allow(military_personnel_service).to receive(:get_service_history)
            .and_raise(StandardError.new('Service history failed'))
        end

        it 'logs the error and returns UNKNOWN_SERVICE_RESPONSE' do
          expect(Rails.logger).to receive(:error).with(/VAProfile::MilitaryPersonnel \(Service History\) error/,
                                                       anything)

          result = subject.status_card

          expect(result[:type]).to eq('veteran_status_alert')
          expect(result[:veteran_status]).to eq('not confirmed')
          expect(result[:attributes][:header]).to eq(VeteranStatusCard::Constants::UNKNOWN_SERVICE_RESPONSE[:title])
          expect(result[:attributes][:body]).to eq(VeteranStatusCard::Constants::UNKNOWN_SERVICE_RESPONSE[:message])
          expect(result[:attributes][:alert_type]).to eq(VeteranStatusCard::Constants::UNKNOWN_SERVICE_RESPONSE[:status])
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
          expect(Rails.logger).to receive(:error).with(/VeteranStatusCard::Service error/, anything)

          result = subject.status_card

          expect(result[:type]).to eq('veteran_status_alert')
          expect(result[:veteran_status]).to eq('not confirmed')
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

      context 'when military_personnel_service.get_service_history returns nil' do
        let(:veteran_status) { 'confirmed' }

        before do
          allow(military_personnel_service).to receive(:get_service_history).and_return(nil)
        end

        it 'returns UNKNOWN_SERVICE_RESPONSE alert' do
          result = subject.status_card

          expect(result[:type]).to eq('veteran_status_alert')
          expect(result[:veteran_status]).to eq('not confirmed')
          expect(result[:attributes][:header]).to eq(VeteranStatusCard::Constants::UNKNOWN_SERVICE_RESPONSE[:title])
          expect(result[:attributes][:body]).to eq(VeteranStatusCard::Constants::UNKNOWN_SERVICE_RESPONSE[:message])
          expect(result[:attributes][:alert_type]).to eq(VeteranStatusCard::Constants::UNKNOWN_SERVICE_RESPONSE[:status])
        end
      end

      context 'when service_history response has nil episodes' do
        let(:veteran_status) { 'confirmed' }
        let(:service_history_response) do
          instance_double(
            VAProfile::MilitaryPersonnel::ServiceHistoryResponse,
            episodes: nil
          )
        end

        it 'returns UNKNOWN_SERVICE_RESPONSE alert' do
          result = subject.status_card

          expect(result[:type]).to eq('veteran_status_alert')
          expect(result[:veteran_status]).to eq('not confirmed')
          expect(result[:attributes][:header]).to eq(VeteranStatusCard::Constants::UNKNOWN_SERVICE_RESPONSE[:title])
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

      context 'when service episodes are empty array' do
        let(:veteran_status) { 'confirmed' }
        let(:service_episodes) { [] }

        it 'returns UNKNOWN_SERVICE_RESPONSE alert' do
          result = subject.status_card

          expect(result[:type]).to eq('veteran_status_alert')
          expect(result[:veteran_status]).to eq('not confirmed')
          expect(result[:attributes][:header]).to eq(VeteranStatusCard::Constants::UNKNOWN_SERVICE_RESPONSE[:title])
          expect(result[:attributes][:body]).to eq(VeteranStatusCard::Constants::UNKNOWN_SERVICE_RESPONSE[:message])
          expect(result[:attributes][:alert_type]).to eq(VeteranStatusCard::Constants::UNKNOWN_SERVICE_RESPONSE[:status])
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
        expect(result[:veteran_status]).to eq('not confirmed')
        expect(result[:attributes][:header]).to eq('Test Title')
        expect(result[:attributes][:body]).to eq(['Test Message'])
        expect(result[:attributes][:alert_type]).to eq('error')
      end
    end
  end
end
