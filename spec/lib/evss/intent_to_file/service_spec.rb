# frozen_string_literal: true

require 'rails_helper'

describe EVSS::IntentToFile::Service do
  describe '.find_by_user' do
    let(:user) { build(:user, :loa3) }
    subject { described_class.new(user) }

    describe '#get_intent_to_file' do
      context 'with a valid evss response' do
        it 'returns an intent to file response object' do
          VCR.use_cassette('evss/intent_to_file/intent_to_file') do
            response = subject.get_intent_to_file
            expect(response).to be_ok
            expect(response).to be_an EVSS::IntentToFile::IntentToFilesResponse
            expect(response.intent_to_file.count).to eq 5
          end
        end

        it 'should increment intent_to_file total' do
          VCR.use_cassette('evss/intent_to_file/intent_to_file') do
            expect { subject.get_intent_to_file }.to trigger_statsd_increment('api.evss.get_intent_to_file.total')
          end
        end
      end

      context 'with an http timeout' do
        before do
          allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(Faraday::TimeoutError)
        end

        it 'should log an error and raise GatewayTimeout' do
          expect(StatsD).to receive(:increment).once.with(
            'api.evss.get_intent_to_file.fail', tags: ['error:Common::Exceptions::GatewayTimeout']
          )
          expect(StatsD).to receive(:increment).once.with('api.evss.get_intent_to_file.total')
          expect { subject.get_intent_to_file }.to raise_error(Common::Exceptions::GatewayTimeout)
        end
      end
    end

    describe '#get_active_compensation' do
      context 'with a valid evss response' do
        it 'returns an active compensation response object' do
          VCR.use_cassette('evss/intent_to_file/active_compensation') do
            response = subject.get_active_compensation
            expect(response).to be_ok
            expect(response).to be_an EVSS::IntentToFile::IntentToFileResponse
          end
        end

        it 'should increment intent_to_file total' do
          VCR.use_cassette('evss/intent_to_file/active_compensation') do
            expect { subject.get_active_compensation }.to trigger_statsd_increment('api.evss.get_active_compensation.total')
          end
        end
      end

      context 'with an http timeout' do
        before do
          allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(Faraday::TimeoutError)
        end

        it 'should log an error and raise GatewayTimeout' do
          expect(StatsD).to receive(:increment).once.with(
            'api.evss.get_active_compensation.fail', tags: ['error:Common::Exceptions::GatewayTimeout']
          )
          expect(StatsD).to receive(:increment).once.with('api.evss.get_active_compensation.total')
          expect { subject.get_active_compensation }.to raise_error(Common::Exceptions::GatewayTimeout)
        end
      end
    end

    describe '#create_intent_to_file_compensation' do
      let(:valid_request_body) { '{ "source": "VETS.GOV" }' }
      context 'with a valid intent to file request' do
        subject { described_class.new(user).create_intent_to_file_compensation(valid_request_body) }
        it 'returns an active compensation response object' do
          VCR.use_cassette('evss/intent_to_file/create_intent_to_file_compensation') do
            response = subject
            expect(response).to be_ok
            expect(response).to be_an EVSS::IntentToFile::IntentToFileResponse
          end
        end

        it 'should increment create_intent_to_file_compensation total' do
          VCR.use_cassette('evss/intent_to_file/create_intent_to_file_compensation') do
            expect { subject }.to trigger_statsd_increment('api.evss.create_intent_to_file_compensation.total')
          end
        end
      end

      context 'with an http timeout' do
        before do
          allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::TimeoutError)
        end

        it 'should log an error and raise GatewayTimeout' do
          expect(StatsD).to receive(:increment).once.with(
            'api.evss.create_intent_to_file_compensation.fail', tags: ['error:Common::Exceptions::GatewayTimeout']
          )
          expect(StatsD).to receive(:increment).once.with('api.evss.create_intent_to_file_compensation.total')
          expect { subject.create_intent_to_file_compensation(valid_request_body) }.to raise_error(Common::Exceptions::GatewayTimeout)
        end
      end
    end
  end
end
