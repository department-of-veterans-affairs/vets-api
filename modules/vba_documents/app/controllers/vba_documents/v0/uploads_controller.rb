# frozen_string_literal: true

require_dependency 'vba_documents/application_controller'

module VBADocuments
  module V0
    class UploadsController < ApplicationController
      skip_before_action(:authenticate)

      def create
        submission = VBADocuments::UploadSubmission.create
        render status: :accepted,
               json: submission,
               serializer: VBADocuments::UploadSerializer,
               render_location: true
      end

      def show
        submission = VBADocuments::UploadSubmission.find_by(guid: params[:id])
        render json: submission,
               serializer: VBADocuments::UploadSerializer,
               render_location: false
      end
    end
  end
end
