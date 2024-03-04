# frozen_string_literal: true

module V0
  class AdminController < ApplicationController
    service_tag 'platform-base'
    skip_before_action :authenticate, only: :status

    def status
      app_status = {
        git_revision: AppInfo::GIT_REVISION,
        db_url: nil
      }
      Rails.logger.info("CX Event", {"transaction_type" => "Admin", "transaction_id" => request.request_id, "status" => "Processed", "user_icn" => nil})
      render json: app_status
    end
  end
end
