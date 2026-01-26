# frozen_string_literal: true

require 'rails_helper'
require 'evss/letters/download_service'
require 'evss/letters/letter' # included in test to access LETTER_TYPES

describe EVSS::Letters::DownloadService do
  describe '.find_by_user' do
    subject { described_class.new(user) }

    let(:user) { build(:user, :loa3) }
    let(:letter_type) { 'commissary' }

    describe '#download_by_type' do
      it 'letter type is valid' do
        expect(EVSS::Letters::Letter::LETTER_TYPES).to include letter_type
      end

      it 'foreign_medical_program is a valid letter type' do
        expect(EVSS::Letters::Letter::LETTER_TYPES).to include 'foreign_medical_program'
      end

      context 'without options' do
        it 'downloads a pdf' do
          VCR.use_cassette('evss/letters/download') do
            response = subject.download_letter(letter_type)
            expect(response).to include('%PDF-1.4')
          end
        end

        it 'increments downloads total' do
          VCR.use_cassette('evss/letters/download') do
            expect do
              subject.download_letter(letter_type)
            end.to trigger_statsd_increment('api.evss.download_letter.total')
          end
        end

        context 'when an error occurs' do
          before do
            allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(Faraday::TimeoutError)
          end

          it 'logs increment download fail' do
            expect(StatsD).to receive(:increment).once.with(
              'api.evss.download_letter.fail', tags: ['error:CommonExceptionsGatewayTimeout']
            )
            expect(StatsD).to receive(:increment).once.with('api.evss.download_letter.total')
            expect do
              subject.download_letter(letter_type)
            end.to raise_error(Common::Exceptions::GatewayTimeout)
          end
        end

        context 'when an BackendServiceException occurs' do
          it 'tests that a backend service exception is raised' do
            allow_any_instance_of(described_class).to(
              receive(:download_letter).and_raise(Common::Exceptions::BackendServiceException)
            )
            expect do
              subject.download_letter(letter_type)
            end.to raise_error(Common::Exceptions::BackendServiceException)
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
            response = subject.download_letter(
              letter_type,
              options
            )
            expect(response).to include('%PDF-1.4')
          end
        end

        it 'increments downloads total' do
          VCR.use_cassette('evss/letters/download_options') do
            expect do
              subject.download_letter(
                letter_type,
                options
              )
            end.to trigger_statsd_increment('api.evss.download_letter.total')
          end
        end
      end
    end
  end
end
