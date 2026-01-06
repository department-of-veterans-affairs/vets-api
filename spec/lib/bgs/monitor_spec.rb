# frozen_string_literal: true

require 'rails_helper'
require 'bgs/monitor'

RSpec.describe BGS::Monitor do
  subject(:monitor) { described_class.new }

  describe '#info' do
    it 'logs info level event' do
      expect(StatsD).to receive(:increment).with('bgs', tags: ['service:bgs', 'function:log_event', 'action:test'])
      expect(Rails.logger).to receive(:info).with('test message',
                                                  hash_including(context: { tags: ['action:test'], action: 'test' }))
      monitor.info('test message', 'test')
    end
  end

  describe '#error' do
    it 'logs error level event' do
      expect(StatsD).to receive(:increment).with('bgs',
                                                 tags: ['service:bgs', 'function:log_event', 'action:error_test'])
      expect(Rails.logger).to receive(:error).with('error message',
                                                   hash_including(context: { tags: ['action:error_test'],
                                                                             action: 'error_test' }))
      monitor.error('error message', 'error_test')
    end
  end

  describe '#warn' do
    it 'logs warning level event' do
      expect(StatsD).to receive(:increment).with('bgs', tags: ['service:bgs', 'function:log_event', 'action:warn_test'])
      expect(Rails.logger).to receive(:warn).with('warning message',
                                                  hash_including(context: { tags: ['action:warn_test'],
                                                                            action: 'warn_test' }))
      monitor.warn('warning message', 'warn_test')
    end
  end

  describe '#append_tags' do
    it 'appends tags to context' do
      context = {}
      result = monitor.send(:append_tags, context, action: 'test', type: 'spec')
      expect(result[:tags]).to contain_exactly('action:test', 'type:spec')
    end

    it 'handles existing tags' do
      context = { tags: ['existing:tag'] }
      monitor.send(:append_tags, context, action: 'test')
      expect(context[:tags]).to contain_exactly('existing:tag', 'action:test')
    end
  end
end
