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
      server_name: 'Johnnys-MacBook-Pro.local',
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
            type: 'Common::Exceptions::GatewayTimeout',
            value: 'Common::Exceptions::GatewayTimeout',
            module: 'Common::Exceptions',
            stacktrace: nil
          }
        ]
      },
      message: 'Common::Exceptions::GatewayTimeout: Gateway timeout'
    }
  end

  context 'for Common::Exceptions::GatewayTimeout errors' do
    it 'sets the :level to 30 (warning)' do
      expect(result[:level]).to eq(30)
    end
  end
end
