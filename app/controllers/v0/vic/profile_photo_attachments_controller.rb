# frozen_string_literal: true

module V0
  module VIC
    class ProfilePhotoAttachmentsController < ApplicationController
      skip_before_action :authenticate, only: :create

      # Taken from: https://stackoverflow.com/questions/7905929/how-to-test-valid-uuid-guid/13653180#13653180
      GUID_PATTERN = /[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}/i

      def create
        form_attachment = ::VIC::ProfilePhotoAttachment.new

        form_attachment.set_file_data!(
          params[:profile_photo_attachment][:file_data],
          get_in_progress_form
        )
        form_attachment.save!

        render(json: form_attachment, is_anonymous_upload: @current_user.blank?)
      end

      def show
        guid = params[:id]

        raise Common::Exceptions::RecordNotFound, guid unless GUID_PATTERN.match(guid)

        form_attachment = ::VIC::ProfilePhotoAttachment.where(guid: guid).first
        file = form_attachment.get_file
        send_data(file.read, filename: file.filename, type: file.content_type, disposition: :inline)
      end

      private

      def get_in_progress_form
        return nil if @current_user.blank?

        form = InProgressForm.where(form_id: 'VIC', user_uuid: @current_user.uuid)
                             .first_or_initialize(form_data: '{}', metadata: {})
        form.save!
        form
      end
    end
  end
end
