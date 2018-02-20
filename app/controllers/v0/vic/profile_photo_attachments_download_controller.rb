# frozen_string_literal: true

module V0
  module VIC
    class ProfilePhotoAttachmentsDownloadController < ApplicationController
      include ActionController::Live

      # Taken from: https://stackoverflow.com/questions/7905929/how-to-test-valid-uuid-guid/13653180#13653180
      GUID_PATTERN = /[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/i

      def show
        guid = params[:id]

        raise ActiveRecord::RecordNotFound unless GUID_PATTERN.match(guid)

        form_attachment = ::VIC::ProfilePhotoAttachment.where(guid: guid).first
        file = form_attachment.get_file

        headers['Content-Type'] = file.content_type
        headers['Content-Disposition'] = "inline; filename=\"#{file.filename}\""
        file.read { |c| response.stream.write(c) }
      ensure
        response.stream.close
      end
    end
  end
end
