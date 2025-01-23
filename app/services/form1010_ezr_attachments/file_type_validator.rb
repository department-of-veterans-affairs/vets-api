# frozen_string_literal: true

require 'form1010_ezr/service'

module Form1010EzrAttachments
  class FileTypeValidator
    def initialize(file)
      @file = file
    end

    # This method was created because there's an issue on the frontend where a user can manually 'change' a
    # file's extension via its name in order to circumvent frontend validation. '.xlsx' files, in particular, were
    # the cause of several form submission failures. With that said, we need to check the actual file type
    # and ensure the Enrollment System accepts it.
    def validate
      file_path = @file.tempfile.path
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

    private

    # These MIME types correspond to the extensions accepted by enrollment system: PDF,WORD,JPG,RTF
    def mime_subtype_allow_list
      %w[pdf msword vnd.openxmlformats-officedocument.wordprocessingml.document jpeg rtf png]
    end
  end
end
