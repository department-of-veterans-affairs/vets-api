# frozen_string_literal: true

require_dependency 'vba_documents/application_controller'
require_dependency 'vba_documents/upload_error'

module VBADocuments
  module V0
    class UploadsController < ApplicationController
      skip_before_action(:authenticate)

      def create
        submission = VBADocuments::UploadSubmission.create(consumer_name: request.headers['X-Consumer-Username'])
        render status: :accepted,
               json: submission,
               serializer: VBADocuments::UploadSerializer,
               render_location: true
      end

      def show
        submission = VBADocuments::UploadSubmission.find_by(guid: params[:id])
        if submission.nil? || submission.status == 'expired'
          render status: :not_found,
                 json: VBADocuments::UploadSubmission.fake_status(params[:id]),
                 serializer: VBADocuments::UploadSerializer,
                 render_location: false
        else
          submission.refresh_status!
          render json: submission,
                 serializer: VBADocuments::UploadSerializer,
                 render_location: false
        end
      end
    end
  end
end
