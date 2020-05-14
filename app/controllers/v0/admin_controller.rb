# frozen_string_literal: true

module V0
  class AdminController < ApplicationController
    skip_before_action :authenticate, only: :status

    def status
      app_status = {
        "git_revision": AppInfo::GIT_REVISION,
        "db_url": nil
      }
      render json: app_status
    end

    def bill
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
      # comment
    end
  end
end
