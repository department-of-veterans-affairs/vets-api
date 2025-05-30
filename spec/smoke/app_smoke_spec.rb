# frozen_string_literal: true

# rubocop:disable RSpec/DescribeClass
require 'rails_helper'

# Define a minimal job class that we can enqueue
class SmokeDummyJob
  include Sidekiq::Job
  def perform; end
end

RSpec.describe 'Application smoke test' do
  it 'connects to the database' do
    expect(ActiveRecord::Base.connection).to be_active
  end

  it 'responds to Redis ping' do
    expect($redis.ping).to eq('PONG')
  end

  it 'queues a Sidekiq job' do
    expect do
      SmokeDummyJob.perform_async
    end.to change { Sidekiq::Queues['default'].size }.by(1)
  end
end
# rubocop:enable RSpec/DescribeClass
