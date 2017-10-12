module Common
  module Client
    module FileUpload
      def get_upload_io_object(file_path)
        Faraday::UploadIO.new(
          file_path,
          MimeMagic.by_path(file_path)
        )
      end
    end
  end
end
