# frozen_string_literal: true

require 'rails_helper'

describe HCA::SOAPParser do
  let(:parser) { described_class.new }

  describe '#on_complete' do
    let(:reraised_error) { Common::Client::Errors::HTTPError }

    subject do
      env = double
      allow(env).to receive(:url).and_raise(Common::Client::Errors::HTTPError)
      allow(env).to receive(:body).and_return(body)

      expect { parser.on_complete(env) }.to raise_error(reraised_error)
    end

    context 'with a validation error' do
      let(:reraised_error) { HCA::SOAPParser::ValidationError }
      let(:body) { File.read('spec/fixtures/hca/validation_error.xml') }

      it 'should tag and log validation errors' do
        expect(StatsD).to receive(:increment).with('api.hca.validation_fail')
        expect(Raven).to receive(:tags_context).with(validation: 'hca')

        subject
      end
    end

    context 'with no validation error' do
      let(:body) { '<?xml version="1.0" ?><metadata></metadata>' }

      it 'should not increment statsd' do
        expect(StatsD).not_to receive(:increment).with('api.hca.validation_fail')

        subject
      end
    end
  end
end
