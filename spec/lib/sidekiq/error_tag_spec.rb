# frozen_string_literal: true

require 'rails_helper'

describe Sidekiq::ErrorTag do
  class TestJob
    include Sidekiq::Worker

    def perform; end
  end

  it 'should tag raven before each sidekiq job' do
    TestJob.perform_async
    expect(Raven).to receive(:tags_context).with(job: 'TestJob')
    TestJob.drain
  end
end
