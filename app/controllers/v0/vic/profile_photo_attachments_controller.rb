# frozen_string_literal: true

module V0
  module VIC
    class ProfilePhotoAttachmentsController < ApplicationController
      skip_before_action :authenticate, except: :show

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
        form_attachment = ::VIC::ProfilePhotoAttachment.where(guid: params[:id]).first
        render(json: form_attachment)
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
