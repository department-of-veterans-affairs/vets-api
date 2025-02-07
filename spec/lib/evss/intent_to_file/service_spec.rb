# frozen_string_literal: true

require 'rails_helper'
require 'evss/intent_to_file/service'

describe EVSS::IntentToFile::Service do
  # TODO remove this file
  describe '.find_by_user' do
    subject { described_class.new(user) }

    let(:user) { build(:user, :loa3) }

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

        it 'increments intent_to_file total' do
          VCR.use_cassette('evss/intent_to_file/intent_to_file') do
            expect { subject.get_intent_to_file }.to trigger_statsd_increment('api.evss.get_intent_to_file.total')
          end
        end
      end

      context 'with an http timeout' do
        before do
          allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(Faraday::TimeoutError)
        end

        it 'logs an error and raise GatewayTimeout' do
          expect(StatsD).to receive(:increment).once.with(
            'api.evss.get_intent_to_file.fail', tags: ['error:CommonExceptionsGatewayTimeout']
          )
          expect(StatsD).to receive(:increment).once.with('api.evss.get_intent_to_file.total')
          expect { subject.get_intent_to_file }.to raise_error(Common::Exceptions::GatewayTimeout)
        end
      end

      context 'with a evss internal server error' do
        it 'logs an error and raise a ServiceException' do
          VCR.use_cassette('evss/intent_to_file/intent_to_file_service_error') do
            expect(StatsD).to receive(:increment).once.with(
              'api.evss.get_intent_to_file.fail', tags: ['error:CommonClientErrorsClientError', 'status:500']
            )
            expect(StatsD).to receive(:increment).once.with('api.evss.get_intent_to_file.total')
            expect { subject.get_intent_to_file }.to raise_error(EVSS::IntentToFile::ServiceException)
          end
        end
      end
    end

    describe '#get_active' do
      context 'with a valid evss response' do
        it 'returns an active compensation response object' do
          VCR.use_cassette('evss/intent_to_file/active_compensation') do
            response = subject.get_active('compensation')
            expect(response).to be_ok
            expect(response).to be_an EVSS::IntentToFile::IntentToFileResponse
          end
        end

        it 'increments intent_to_file total' do
          VCR.use_cassette('evss/intent_to_file/active_compensation') do
            expect do
              subject.get_active('compensation')
            end.to trigger_statsd_increment('api.evss.get_active.total')
          end
        end
      end

      context 'with an http timeout' do
        before do
          allow_any_instance_of(Faraday::Connection).to receive(:get).and_raise(Faraday::TimeoutError)
        end

        it 'logs an error and raise GatewayTimeout' do
          expect(StatsD).to receive(:increment).once.with(
            'api.evss.get_active.fail', tags: ['error:CommonExceptionsGatewayTimeout']
          )
          expect(StatsD).to receive(:increment).once.with('api.evss.get_active.total')
          expect { subject.get_active('compensation') }.to raise_error(Common::Exceptions::GatewayTimeout)
        end
      end

      context 'with a evss partner service invalid error' do
        it 'logs an error and raise a ServiceException' do
          VCR.use_cassette('evss/intent_to_file/active_compensation_partner_service_invalid') do
            expect(StatsD).to receive(:increment).once.with(
              'api.evss.get_active.fail', tags: ['error:CommonClientErrorsClientError', 'status:502']
            )
            expect(StatsD).to receive(:increment).once.with('api.evss.get_active.total')
            expect { subject.get_active('compensation') }.to raise_error(EVSS::IntentToFile::ServiceException)
          end
        end
      end
    end

    describe '#create_intent_to_file' do
      context 'with a valid intent to file request' do
        subject { described_class.new(user).create_intent_to_file('compensation') }

        it 'returns an active compensation response object' do
          VCR.use_cassette('evss/intent_to_file/create_compensation') do
            response = subject
            expect(response).to be_ok
            expect(response).to be_an EVSS::IntentToFile::IntentToFileResponse
          end
        end

        it 'increments create_intent_to_file total' do
          VCR.use_cassette('evss/intent_to_file/create_compensation') do
            expect { subject }.to trigger_statsd_increment('api.evss.create_intent_to_file.total')
          end
        end
      end

      context 'with an http timeout' do
        before do
          allow_any_instance_of(Faraday::Connection).to receive(:post).and_raise(Faraday::TimeoutError)
        end

        it 'logs an error and raise GatewayTimeout' do
          expect(StatsD).to receive(:increment).once.with(
            'api.evss.create_intent_to_file.fail', tags: ['error:CommonExceptionsGatewayTimeout']
          )
          expect(StatsD).to receive(:increment).once.with('api.evss.create_intent_to_file.total')
          expect do
            subject.create_intent_to_file('compensation')
          end.to raise_error(Common::Exceptions::GatewayTimeout)
        end
      end

      context 'with an invalid intent to file type' do
        subject { described_class.new(user).create_intent_to_file('compensation') }

        it 'logs an error and raise a ServiceException' do
          VCR.use_cassette('evss/intent_to_file/create_compensation_type_error') do
            expect(StatsD).to receive(:increment).once.with(
              'api.evss.create_intent_to_file.fail',
              tags: ['error:CommonClientErrorsClientError', 'status:404']
            )
            expect(StatsD).to receive(:increment).once.with('api.evss.create_intent_to_file.total')
            expect { subject }.to raise_error(EVSS::IntentToFile::ServiceException)
          end
        end
      end

      context 'with a partner service error' do
        subject { described_class.new(user).create_intent_to_file('compensation') }

        it 'logs an error and raise a ServiceException' do
          VCR.use_cassette('evss/intent_to_file/create_compensation_partner_service_error') do
            expect(StatsD).to receive(:increment).once.with(
              'api.evss.create_intent_to_file.fail',
              tags: ['error:CommonClientErrorsClientError', 'status:502']
            )
            expect(StatsD).to receive(:increment).once.with('api.evss.create_intent_to_file.total')
            expect { subject }.to raise_error(EVSS::IntentToFile::ServiceException)
          end
        end
      end

      context 'when service returns a 403' do
        subject { described_class.new(user).create_intent_to_file('compensation') }

        it 'contains 403 in meta' do
          VCR.use_cassette('evss/intent_to_file/create_compensation_403') do
            expect { subject }.to raise_error(Common::Exceptions::Forbidden)
          end
        end
      end
    end
  end
end
