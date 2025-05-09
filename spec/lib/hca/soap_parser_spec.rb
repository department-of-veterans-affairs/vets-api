# frozen_string_literal: true

require 'rails_helper'
require 'hca/soap_parser'

describe HCA::SOAPParser do
  let(:parser) { described_class.new }

  describe '#on_complete' do
    subject do
      env = double
      allow(env).to receive(:url)
      allow(env).to receive(:body=).and_raise(Common::Client::Errors::HTTPError)
      allow(env).to receive_messages(body:, status:)

      expect { parser.on_complete(env) }.to raise_error(reraised_error)
    end

    let(:reraised_error) { Common::Client::Errors::HTTPError }
    let(:status) { 200 }

    context 'with a validation error' do
      let(:reraised_error) { HCA::SOAPParser::ValidationError }
      let(:body) { File.read('spec/fixtures/hca/validation_error.xml') }

      context ':hca_disable_sentry_logs enabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:hca_disable_sentry_logs).and_return(true)
        end

        it 'tags and log validation errors' do
          expect(StatsD).to receive(:increment).with('api.hca.validation_fail')

          expect(Rails.logger).to receive(:error).with(
            '[HCA] - Error in soap parser',
            {
              exception: Common::Client::Errors::HTTPError,
              validation: 'hca'
            }
          )

          subject
        end
      end

      context ':hca_disable_sentry_logs disabled' do
        before do
          allow(Flipper).to receive(:enabled?).with(:hca_disable_sentry_logs).and_return(false)
        end

        it 'tags and log validation errors' do
          expect(StatsD).to receive(:increment).with('api.hca.validation_fail')
          expect(Sentry).to receive(:set_tags).with(validation: 'hca')
          expect_any_instance_of(SentryLogging).to receive(:log_exception_to_sentry)
            .with(Common::Client::Errors::HTTPError)

          subject
        end
      end
    end

    context 'with no validation error' do
      def self.test_body(body)
        let(:body) { body }

        it 'does not increment statsd' do
          expect(StatsD).not_to receive(:increment).with('api.hca.validation_fail')

          subject
        end
      end

      test_body('<?xml version="1.0" ?><metadata></metadata>')

      test_body(File.read('spec/fixtures/hca/mvi_error.xml'))
    end

    context 'with 503 response' do
      let(:status) { 503 }
      let(:reraised_error) { Faraday::TimeoutError }
      let(:body) { '<html><body>No Server Available</body></html>' }

      it 'raises Faraday::TimeoutError' do
        subject
      end
    end
  end
end
