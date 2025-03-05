# frozen_string_literal: true

require 'rails_helper'
require 'evss/letters/service'

describe EVSS::Letters::Service do
  describe '.find_by_user' do
    subject { described_class.new(user) }

    let(:user) { build(:user, :loa3) }

    describe '#get_letters' do
      context 'with a valid evss response' do
        context 'when :letters_hide_service_verification_letter is enabled' do
          before do
            allow(Flipper).to receive(:enabled?).and_call_original
            allow(Flipper).to receive(:enabled?).with(:letters_hide_service_verification_letter).and_return(true)
          end

          it 'excludes the service_verification letter and returns a letters response object' do
            VCR.use_cassette('evss/letters/letters') do
              response = subject.get_letters
              expect(response).to be_ok
              expect(response).to be_a(EVSS::Letters::LettersResponse)
              expect(response.letters.count).to eq(7) # One fewer letter because we don't have service_verification
              expect(response.letters.first.as_json).to eq('name' => 'Commissary Letter', 'letter_type' => 'commissary')
            end
          end

          it 'increments letters total' do
            VCR.use_cassette('evss/letters/letters') do
              expect { subject.get_letters }.to trigger_statsd_increment('api.evss.get_letters.total')
            end
          end
        end

        context 'when :letters_hide_service_verification_letter is disabled' do
          before do
            allow(Flipper).to receive(:enabled?).and_call_original
            allow(Flipper).to receive(:enabled?).with(:letters_hide_service_verification_letter).and_return(false)
          end

          it 'returns a letters response object' do
            VCR.use_cassette('evss/letters/letters') do
              response = subject.get_letters
              expect(response).to be_ok
              expect(response).to be_a(EVSS::Letters::LettersResponse)
              expect(response.letters.count).to eq(8)
              expect(response.letters.first.as_json).to eq('name' => 'Commissary Letter', 'letter_type' => 'commissary')
            end
          end

          it 'increments letters total' do
            VCR.use_cassette('evss/letters/letters') do
              expect { subject.get_letters }.to trigger_statsd_increment('api.evss.get_letters.total')
            end
          end
        end
      end

      context 'with an http timeout' do
        before do
          allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(Faraday::TimeoutError)
        end

        it 'logs an error and raise GatewayTimeout' do
          expect(StatsD).to receive(:increment).once.with(
            'api.evss.get_letters.fail', tags: ['error:CommonExceptionsGatewayTimeout']
          )
          expect(StatsD).to receive(:increment).once.with('api.evss.get_letters.total')
          expect(Sentry).to receive(:set_tags).once.with(team: 'benefits-memorial-1')
          expect { subject.get_letters }.to raise_error(Common::Exceptions::GatewayTimeout)
        end
      end

      context 'with an unknown error from EVSS' do
        it 'raises a BackendServiceException' do
          VCR.use_cassette('evss/letters/letters_unexpected_error') do
            expect(Sentry).to receive(:set_tags).once.with(team: 'benefits-memorial-1')
            expect { subject.get_letters }.to raise_error(Common::Exceptions::BackendServiceException) do |e|
              expect(e.message).to match(/EVSS502/)
            end
          end
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

      it 'increments beneficiary total' do
        VCR.use_cassette('evss/letters/beneficiary') do
          expect { subject.get_letter_beneficiary }.to trigger_statsd_increment(
            'api.evss.get_letter_beneficiary.total'
          )
        end
      end

      context 'with an http timeout' do
        before do
          allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(Faraday::TimeoutError)
        end

        it 'logs an error and raise GatewayTimeout' do
          expect(StatsD).to receive(:increment).once.with(
            'api.evss.get_letter_beneficiary.fail', tags: ['error:CommonExceptionsGatewayTimeout']
          )
          expect(StatsD).to receive(:increment).once.with('api.evss.get_letter_beneficiary.total')
          expect(Sentry).to receive(:set_tags).once.with(team: 'benefits-memorial-1')
          expect { subject.get_letter_beneficiary }.to raise_error(Common::Exceptions::GatewayTimeout)
        end
      end
    end
  end
end
