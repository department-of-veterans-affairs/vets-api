# frozen_string_literal: true

module V0
  class AdminController < ApplicationController
    skip_before_action :authenticate, only: :status

    def status
      load './test_files/pdf_21x21.rb'

      app_status = {
        "git_revision": AppInfo::GIT_REVISION,
        "db_url": nil
      }

      # fr = VaForms::FormReloader.new
      # fr.perform
      render json: app_status
    end
  end
end
