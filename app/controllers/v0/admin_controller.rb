# frozen_string_literal: true

require 'admin/postgres_check'

module V0
  class AdminController < ApplicationController
    service_tag 'platform-base'
    skip_before_action :authenticate, only: :status

    def status
      app_status = {
        git_revision: AppInfo::GIT_REVISION,
        db_url: nil,
        postgres_up: DatabaseHealthChecker.postgres_up
      }
      render json: app_status
    end
  end
end
