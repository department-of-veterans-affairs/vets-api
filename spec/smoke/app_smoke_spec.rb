# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Application smoke test' do
  it 'connects to the database' do
    expect(ActiveRecord::Base.connection).to be_active
  end

  it 'responds to Redis ping' do
    expect($redis.ping).to eq('PONG')
  end

  it 'queues a Sidekiq job' do
    class SmokeDummyJob
      include Sidekiq::Job
      def perform; end
    end

    expect {
      SmokeDummyJob.perform_async
    }.to change { Sidekiq::Queues['default'].size }.by(1)
  end
end 