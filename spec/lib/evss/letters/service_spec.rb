# frozen_string_literal: true
require 'rails_helper'

describe EVSS::Letters::Service do
  describe '.find_by_user' do
    let(:user) { build(:loa3_user) }
    let(:auth_headers) { EVSS::AuthHeaders.new(user).to_h }

    subject { described_class.new(auth_headers) }

    describe '#get_letters' do
      context 'with a valid evss response' do
        it 'returns a letters response object' do
          VCR.use_cassette('evss/letters/letters') do
            response = subject.get_letters
            expect(response).to be_ok
            expect(response).to be_a(EVSS::Letters::LettersResponse)
            expect(response.letters.count).to eq(8)
            expect(response.letters.first.as_json).to eq('name' => 'Commissary Letter', 'letter_type' => 'commissary')
          end
        end
      end
      context 'with an http timeout' do
        before do
          allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(Faraday::TimeoutError)
        end

        it 'should log an error and raise GatewayTimeout' do
          expect(Rails.logger).to receive(:error).with(/Timeout/)
          expect { subject.get_letters }.to raise_error(Common::Exceptions::GatewayTimeout)
        end
      end
    end

    describe '#get_letter_beneficiary' do
      it 'returns a letter beneficiary response object' do
        VCR.use_cassette('evss/letters/beneficiary') do
          response = subject.get_letter_beneficiary
          expect(response).to be_ok
          expect(response).to be_a(EVSS::Letters::BeneficiaryResponse)
          expect(response.military_service.count).to eq(2)
        end
      end
      context 'with an http timeout' do
        before do
          allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(Faraday::TimeoutError)
        end

        it 'should log an error and raise GatewayTimeout' do
          expect(Rails.logger).to receive(:error).with(/Timeout/)
          expect { subject.get_letter_beneficiary }.to raise_error(Common::Exceptions::GatewayTimeout)
        end
      end
    end

    describe '#download_by_type' do
      context 'without options' do
        it 'downloads a pdf' do
          VCR.use_cassette('evss/letters/download') do
            response = subject.download_by_type(EVSS::Letters::Letter::LETTER_TYPES.first)
            expect(response).to include('%PDF-1.4')
          end
        end
      end

      context 'with options' do
        let(:options) do
          '{
             "militaryService": false,
             "serviceConnectedDisabilities": false,
             "serviceConnectedEvaluation": false,
             "nonServiceConnectedPension": false,
             "monthlyAward": false,
             "unemployable": false,
             "specialMonthlyCompensation": false,
             "adaptedHousing": false,
             "chapter35Eligibility": false,
             "deathResultOfDisability": false,
             "survivorsAward": false
           }'
        end
        it 'downloads a pdf' do
          VCR.use_cassette('evss/letters/download_options') do
            response = subject.download_by_type(
              EVSS::Letters::Letter::LETTER_TYPES.first,
              options
            )
            expect(response).to include('%PDF-1.4')
          end
        end
      end
    end
  end
end
