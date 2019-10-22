# frozen_string_literal: true

require 'rails_helper'

describe Sidekiq::ErrorTag do
  # rubocop:disable Style/GlobalVars
  class TestJob
    include Sidekiq::Worker

    def make_request
      $named_tags = Sidekiq::Logging.logger.named_tags
    end
  end

  before do
    allow_any_instance_of(ApplicationController).to receive(:request).and_return(
      OpenStruct.new(
        uuid: '123',
        remote_ip: '99.99.99.99',
        user_agent: 'banana'
      )
    )
    ApplicationController.new.send(:set_tags_and_extra_context)
  end

  it 'tags raven before each sidekiq job' do
    TestJob.perform_async
    expect(Raven).to receive(:tags_context).with(request_id: '123')
    expect(Raven).to receive(:tags_context).with(job: 'TestJob')
    TestJob.drain
  end

  it 'adds controller metadata to semantic logger named tags' do
    Sidekiq::Testing.inline! do
      TestJob.perform_async
      expect($named_tags[:request_id]).to eq('123')
      expect($named_tags[:remote_ip]).to eq('99.99.99.99')
      expect($named_tags[:user_agent]).to eq('banana')
    end
  end
  # rubocop:enable Style/GlobalVars
end
