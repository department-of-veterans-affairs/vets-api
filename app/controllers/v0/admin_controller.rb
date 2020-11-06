# frozen_string_literal: true
require_dependency './modules/vba_documents/app/workers/vba_documents/upload_processor'
module V0
  class AdminController < ApplicationController
    skip_before_action :authenticate, only: :status

    def status
      app_status = {
        "git_revision": AppInfo::GIT_REVISION,
        "db_url": nil
      }
      VBADocuments::UploadProcessor.new.perform('0324b07a-7fa3-4d12-adf7-4c6b7dbe7115')
      render json: app_status
    end
  end
end
