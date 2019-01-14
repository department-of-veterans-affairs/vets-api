# frozen_string_literal: true

require 'rails_helper'

describe Sentry::Processor::CoerceServiceExceptionMessage do
  let(:client) { double('client') }
  let(:processor) { Sentry::Processor::CoerceServiceExceptionMessage.new(client) }
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
        message: 'Common::Exceptions::BackendServiceException'
      },
      exception: {
        values: [
          {
            type: exception,
            value: 'Common::Exceptions::BackendServiceException',
            module: 'Common::Exceptions',
            stacktrace: nil
          }
        ]
      },
      message: 'Common::Exceptions::BackendServiceException:'
    }
  end

  context 'for Common::Exceptions::BackendServiceException errors' do
    let(:exception) { Common::Exceptions::BackendServiceException.to_s }
    it 'changes the message a bit' do
      expect(processor.process(data)[:message]).to eq('Common::Exceptions::BackendServiceException: msg')
    end
  end
end

