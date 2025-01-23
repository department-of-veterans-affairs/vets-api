# frozen_string_literal: true

require 'rails_helper'
require 'admin/redis_health_checker'

RSpec.describe 'V0::Status', type: :request do
  before do
    allow(RedisHealthChecker).to receive_messages(redis_up: true, app_data_redis_up: true, rails_cache_up: true,
                                                  sidekiq_redis_up: true)
  end

  it 'Provides a status page with status OK, git SHA, and connectivity statuses' do
    get '/v0/status'
    assert_response :success

    json = JSON.parse(response.body)
    git_rev = AppInfo::GIT_REVISION
    pg_up = DatabaseHealthChecker.postgres_up

    expect(response.headers['X-Git-SHA']).to eq(git_rev)
    expect(json['git_revision']).to eq(git_rev)
    expect(json['postgres_up']).to eq(pg_up)
    expect(json['redis_up']).to be(true)
    expect(json['redis_details']).to eq({
                                          'app_data_redis' => true,
                                          'rails_cache' => true,
                                          'sidekiq_redis' => true
                                        })
  end

  context 'when Redis services are down' do
    before do
      allow(RedisHealthChecker).to receive_messages(redis_up: false, app_data_redis_up: false, rails_cache_up: true,
                                                    sidekiq_redis_up: false)
    end

    it 'reflects the correct Redis statuses' do
      get '/v0/status'
      assert_response :success

      json = JSON.parse(response.body)
      expect(json['redis_up']).to be(false)
      expect(json['redis_details']).to eq({
                                            'app_data_redis' => false,
                                            'rails_cache' => true,
                                            'sidekiq_redis' => false
                                          })
    end
  end
end
