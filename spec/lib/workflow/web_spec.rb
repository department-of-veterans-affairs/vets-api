# frozen_string_literal: true
require 'rails_helper'
require 'sidekiq/web'

Workflow::Web.add_to_sidekiq

describe Workflow::Web do
  include Rack::Test::Methods

  before do
    Sidekiq.redis(&:flushdb)
  end

  def app
    Sidekiq::Web
  end

  def add_retry(job, queue)
    msg = { 'class' => job,
            'args' => ['bob', 1, Time.now.to_f],
            'queue' => queue,
            'error_message' => 'Some fake message',
            'error_class' => 'RuntimeError',
            'retry_count' => 0,
            'failed_at' => Time.now.to_f,
            'jid' => SecureRandom.hex(12) }
    score = Time.now.to_f

    Sidekiq.redis do |conn|
      conn.zadd('retry', score, Sidekiq.dump_json(msg))
    end
  end

  describe '/workflows' do
    it 'should get the workflow retryset' do
      job1 = SecureRandom.uuid
      job2 = SecureRandom.uuid
      add_retry(job1, 'default')
      add_retry(job2, 'tasker')
      get('/workflows')

      expect(last_response.status).to eq(200)

      body = last_response.body
      expect(body).to include(job2)
      expect(body).not_to include(job1)
    end
  end
end
