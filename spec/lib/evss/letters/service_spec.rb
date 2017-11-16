# frozen_string_literal: true
require 'rails_helper'

describe EVSS::Letters::Service do
  describe '.find_by_user' do
    let(:user) { build(:user, :loa3) }

    describe '#get_letters' do
      context 'with a valid evss response' do
        it 'returns a letters response object' do
          VCR.use_cassette('evss/letters/letters') do
            response = subject.get_letters(user)
            expect(response).to be_ok
            expect(response).to be_a(EVSS::Letters::LettersResponse)
            expect(response.letters.count).to eq(8)
            expect(response.letters.first.as_json).to eq('name' => 'Commissary Letter', 'letter_type' => 'commissary')
          end
        end

        it 'should increment letters total' do
          VCR.use_cassette('evss/letters/letters') do
            expect { subject.get_letters(user) }.to trigger_statsd_increment('api.evss.get_letters.total')
          end
        end
      end

      context 'with an http timeout' do
        before do
          allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(Faraday::TimeoutError)
        end

        it 'should log an error and raise GatewayTimeout' do
          expect(Rails.logger).to receive(:error).with(/Timeout/)
          expect(StatsD).to receive(:increment).once.with(
            'api.evss.get_letters.fail', tags: ['error:Common::Exceptions::GatewayTimeout']
          )
          expect(StatsD).to receive(:increment).once.with('api.evss.get_letters.total')
          expect { subject.get_letters(user) }.to raise_error(Common::Exceptions::GatewayTimeout)
        end
      end
    end

    describe '#get_letter_beneficiary' do
      it 'returns a letter beneficiary response object' do
        VCR.use_cassette('evss/letters/beneficiary') do
          response = subject.get_letter_beneficiary(user)
          expect(response).to be_ok
          expect(response).to be_a(EVSS::Letters::BeneficiaryResponse)
          expect(response.military_service.count).to eq(2)
        end
      end

      it 'should increment beneficiary total' do
        VCR.use_cassette('evss/letters/beneficiary') do
          expect { subject.get_letter_beneficiary(user) }.to trigger_statsd_increment(
            'api.evss.get_letter_beneficiary.total'
          )
        end
      end

      context 'with an http timeout' do
        before do
          allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(Faraday::TimeoutError)
        end

        it 'should log an error and raise GatewayTimeout' do
          expect(Rails.logger).to receive(:error).with(/Timeout/)
          expect(StatsD).to receive(:increment).once.with(
            'api.evss.get_letter_beneficiary.fail', tags: ['error:Common::Exceptions::GatewayTimeout']
          )
          expect(StatsD).to receive(:increment).once.with('api.evss.get_letter_beneficiary.total')
          expect { subject.get_letter_beneficiary(user) }.to raise_error(Common::Exceptions::GatewayTimeout)
        end
      end
    end

    describe '#download_by_type' do
      context 'without options' do
        it 'downloads a pdf' do
          VCR.use_cassette('evss/letters/download') do
            response = subject.download_letter(user, EVSS::Letters::Letter::LETTER_TYPES.first)
            expect(response).to include('%PDF-1.4')
          end
        end

        it 'should increment downloads total' do
          VCR.use_cassette('evss/letters/download') do
            expect do
              subject.download_letter(user, EVSS::Letters::Letter::LETTER_TYPES.first)
            end.to trigger_statsd_increment('api.evss.download_letter.total')
          end
        end

        context 'when an error occurs' do
          before do
            allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(Faraday::TimeoutError)
          end

          it 'should log increment download fail' do
            expect(StatsD).to receive(:increment).once.with(
              'api.evss.download_letter.fail', tags: ['error:Faraday::TimeoutError']
            )
            expect(StatsD).to receive(:increment).once.with('api.evss.download_letter.total')
            expect do
              subject.download_letter(user, EVSS::Letters::Letter::LETTER_TYPES.first)
            end.to raise_error(Faraday::TimeoutError)
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
              user,
              EVSS::Letters::Letter::LETTER_TYPES.first,
              options
            )
            expect(response).to include('%PDF-1.4')
          end
        end

        it 'should increment downloads total' do
          VCR.use_cassette('evss/letters/download_options') do
            expect do
              subject.download_letter(
                user,
                EVSS::Letters::Letter::LETTER_TYPES.first,
                options
              )
            end.to trigger_statsd_increment('api.evss.download_letter.total')
          end
        end
      end
    end
  end
end
