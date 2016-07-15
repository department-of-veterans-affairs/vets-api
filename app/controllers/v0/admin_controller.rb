module V0
  class AdminController < ApplicationController
    def status
      app_status = {
        "git_revision": AppInfo::GIT_REVISION,
        "db_url": nil
      }
      render json: app_status
    end
  end
end
