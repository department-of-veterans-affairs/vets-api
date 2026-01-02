# frozen_string_literal: true

require 'admin/postgres_check'
require 'admin/redis_health_checker'

module V0
  class AdminController < ApplicationController
    service_tag 'platform-base'
    skip_before_action :authenticate, only: %i[status debug_headers]

    def status
      app_status = {
        git_revision: AppInfo::GIT_REVISION,
        db_url: nil,
        postgres_up: DatabaseHealthChecker.postgres_up,
        redis_up: RedisHealthChecker.redis_up,
        redis_details: {
          app_data_redis: RedisHealthChecker.app_data_redis_up,
          rails_cache: RedisHealthChecker.rails_cache_up,
          sidekiq_redis: RedisHealthChecker.sidekiq_redis_up
        }
      }
      render json: app_status
    end

    def debug_headers
      render json: {
        ssl?: request.ssl?,
        scheme: request.scheme,
        forwarded_proto: request.headers['X-Forwarded-Proto'],
        forwarded_scheme: request.headers['X-Forwarded-Scheme'],
        remote_ip: request.remote_ip,
        trusted_proxies: Rails.application.config.action_dispatch.trusted_proxies.map(&:to_s)
      }
    end
  end
end
