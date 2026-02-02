# frozen_string_literal: true

require 'admin/postgres_check'
require 'admin/redis_health_checker'

module V0
  class AdminController < ApplicationController
    service_tag 'platform-base'
    skip_before_action :authenticate, only: %i[status header_status]

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

    def header_status
      headers_info = if Settings.vsp_environment == 'production'
                       {}
                     else
                       {
                         'X-Forwarded-Proto': request.headers['HTTP_X_FORWARDED_PROTO'],
                         'X-Forwarded-Scheme': request.headers['HTTP_X_FORWARDED_SCHEME'],
                         'request.ssl?': request.ssl?,
                         'request.protocol': request.protocol,
                         Host: request.host,
                         Port: request.port,
                         'Original-URL': request.original_url,
                         Scheme: request.scheme
                       }
                     end

      render json: headers_info, status: :ok
    end
  end
end
