# frozen_string_literal: true

require 'rails_helper'

describe Sidekiq::ErrorTag do
  class TestJob
    include Sidekiq::Worker

    def perform
      Sidekiq::Logging.logger.warn 'Things are happening.'
    end
  end

  before(:each) do
    Thread.current['request_id'] = '123'
    Thread.current['additional_request_attributes'] = {
      'remote_ip' => '99.99.99.99',
      'user_agent' => 'banana'
    }
  end

  it 'should tag raven before each sidekiq job' do
    TestJob.perform_async
    expect(Raven).to receive(:tags_context).with(request_id: '123')
    expect(Raven).to receive(:tags_context).with(job: 'TestJob')
    TestJob.drain
  end

  it 'should add Thread.current[:request_attributes] to semantic logger named tags' do
    expect(Sidekiq::Logging.logger).to receive(:warn).with('Things are happening.')

    Sidekiq::Testing.inline! do
      TestJob.perform_async
      TestJob.drain
    end
  end
end
