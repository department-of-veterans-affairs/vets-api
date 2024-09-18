# frozen_string_literal: true

require 'form1010_ezr/service'

module V0
  class Form1010EzrAttachmentsController < ApplicationController
    include FormAttachmentCreate
    service_tag 'health-information-update'

    FORM_ATTACHMENT_MODEL = Form1010EzrAttachment

    def create
      validate_file_upload_class!
      validate_file_type
      save_attachment_to_cloud!
      save_attachment_to_db!

      render json: serializer_klass.new(form_attachment)
    end

    private

    def serializer_klass
      Form1010EzrAttachmentSerializer
    end

    # These MIME types correspond to the extensions accepted by enrollment system: PDF,WORD,JPG,RTF
    def mime_subtype_allow_list
      %w[pdf msword vnd.openxmlformats-officedocument.wordprocessingml.document jpeg rtf png]
    end

    # This method was created because there's an issue on the frontend where a user can manually 'change' a
    # file's extension via its name in order to circumvent frontend validation. With that said, we need to check
    # the actual file type and ensure the Enrollment System accepts it
    def validate_file_type
      file_path = filtered_params['file_data'].tempfile.path
      # Using 'MIME::Types' doesn't work here because it will
      # return, for example, 'application/zip' for .docx files
      mime_subtype = IO.popen(
        ['file', '--mime-type', '--brief', file_path]
      ) { |io| io.read.chomp.to_s }.split('/').last

      unless mime_subtype_allow_list.include?(mime_subtype)
        StatsD.increment("#{Form1010Ezr::Service::STATSD_KEY_PREFIX}.attachments.invalid_file_type")

        raise Common::Exceptions::UnprocessableEntity.new(
          detail: 'File type not supported. Follow the instructions on your device ' \
                  'on how to convert the file type and try again to continue.'
        )
      end
    rescue => e
      StatsD.increment("#{Form1010Ezr::Service::STATSD_KEY_PREFIX}.attachments.failed")

      Rails.logger.error(
        "Form1010EzrAttachment validate file type failed #{e.message}.",
        backtrace: e.backtrace
      )
      raise e
    end
  end
end
