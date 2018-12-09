# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Sentry::Processor::LogAsWarning do
  let(:client) { double('client') }
  let(:processor) { Sentry::Processor::LogAsWarning.new(client) }
  let(:result) { processor.process(data) }

  let(:data) do
    {
      event_id: '26eb47ec7a74430f89348c9dda4bda2b',
      timestamp: '2018-11-30T16:03:00',
      time_spent: nil,
      level: 40,
      platform: 'ruby',
      sdk: { 'name' => 'sentry-raven', 'version' => '2.3.0' },
      logger: '',
      server_name: 'cool server',
      release: 'c57d00f70',
      environment: 'default',
      modules: {},
      extra: {},
      tags: {},
      user: {},
      logentry: {
        params: nil,
        message: 'Common::Exceptions::GatewayTimeout: Gateway timeout'
      },
      exception: {
        values: [
          {
            type: exception,
            value: 'Common::Exceptions::GatewayTimeout',
            module: 'Common::Exceptions',
            stacktrace: nil
          }
        ]
      },
      message: 'Common::Exceptions::GatewayTimeout: Gateway timeout'
    }
  end

  %w[
    Common::Exceptions::GatewayTimeout
    EVSS::ErrorMiddleware::EVSSError
    EVSS::DisabilityCompensationForm::GatewayTimeout
  ].each do |error|
    context "for #{error} errors" do
      let(:exception) { error }
      it 'sets the :level to 30 (warning)' do
        expect(processor.process(data)[:level]).to eq(30)
        expect(processor.process(data.deep_stringify_keys)['level']).to eq(30)
      end
    end
  end

  context 'for all other errors' do
    let(:exception) { NoMethodError.to_s }
    it 'does not change the :level' do
      expect(processor.process(data)[:level]).to eq(40)
      expect(processor.process(data.deep_stringify_keys)['level']).to eq(40)
    end
  end
end
