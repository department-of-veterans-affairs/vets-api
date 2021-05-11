# frozen_string_literal: true

module Form1010cg
  class Attachment < FormAttachment
    ATTACHMENT_UPLOADER_CLASS = ::Form1010cg::PoaUploader

    def to_local_file
      remote_file = get_file
      local_path  = "tmp/#{remote_file.path.gsub('/', '_')}"

      File.write(local_path, remote_file.read)

      local_path
    end
  end
end
