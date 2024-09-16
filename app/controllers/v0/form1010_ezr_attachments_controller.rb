# frozen_string_literal: true

module V0
  class Form1010EzrAttachmentsController < ApplicationController
    include FormAttachmentCreate
    service_tag 'health-information-update'

    before_action :validate_file_extension, only: :create

    FORM_ATTACHMENT_MODEL = Form1010EzrAttachment

    private

    def serializer_klass
      Form1010EzrAttachmentSerializer
    end

    # This method was created because there's an issue on the frontend where a user can manually 'change' a
    # file's extension via its name in order to circumvent frontend validation. With that said, we need to check
    # the actual extension and ensure the Enrollment System accepts it
    def validate_file_extension
      extension = MIME::Types[
        params['form1010_ezr_attachment']['file_data'].content_type.to_s
      ]&.first&.extensions&.first

      unless HCAAttachmentUploader.new(nil).extension_allowlist.include?(extension)
        raise Common::Exceptions::UnprocessableEntity.new(
          detail: "The '#{extension}' file extension is not currently supported. Follow the instructions " \
                  'on your device on how to convert the file extension and try again to continue.'
        )
      end
    end
  end
end
