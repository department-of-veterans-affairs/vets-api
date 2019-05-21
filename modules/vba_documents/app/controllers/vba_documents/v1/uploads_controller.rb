# frozen_string_literal: true

require_dependency 'vba_documents/application_controller'
require_dependency 'vba_documents/upload_error'

module VBADocuments
  module V1
    class UploadsController < ApplicationController
      skip_before_action(:authenticate)

      def create
        submission = VBADocuments::UploadSubmission.create(
          consumer_name: request.headers['X-Consumer-Username'],
          consumer_id: request.headers['X-Consumer-ID']
        )

        # raise(Common::Exceptions::RecordNotFound, submission.guid) if submission.status == 'error'

        render status: :accepted,
               json: submission,
               serializer: VBADocuments::V1::UploadSerializer,
               render_location: true
      end

      def show
        submission = VBADocuments::UploadSubmission.find_by(guid: params[:id])

        #  if submission.status == 'error'

        if Settings.vba_documents.enable_status_override && request.headers['Status-Override']
          submission.status = request.headers['Status-Override']
          submission.save
        end

        if submission.nil? || submission.status == 'expired'
          raise Common::Exceptions::RecordNotFound, params[:id]
        else
          submission.refresh_status!
          render json: submission,
                 serializer: VBADocuments::V1::UploadSerializer,
                 render_location: false
        end
      end
    end
  end
end
