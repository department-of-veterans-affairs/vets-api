# frozen_string_literal: true

require 'vba_documents/upload_error'

module VBADocuments
  class PayloadManager
    def self.zip(submission)
      raw_file, = download_raw_file(submission.guid)

      begin
        parsed = VBADocuments::MultipartParser.parse(raw_file.path)
        files = [
          { name: 'content.pdf', path: parsed['content'].path },
          { name: 'metadata.json', path: write_json(submission.guid, parsed).path }
        ] + attachments(parsed)
      rescue VBADocuments::UploadError
        files = [{ name: 'payload.blob', path: raw_file.path }]
      end
      zip_file_name = "/tmp/#{submission.guid}.zip"

      Zip::File.open(zip_file_name, Zip::File::CREATE) do |zipfile|
        files.each do |file|
          zipfile.add(file[:name], file[:path])
        end
      end

      zip_file_name
    end

    def self.download_raw_file(guid)
      store = VBADocuments::ObjectStore.new
      if store.bucket.object(guid).exists?
        tempfile = Tempfile.new(guid)
        version = store.first_version(guid)
        store.download(version, tempfile.path)
        [tempfile, version.last_modified]
      else
        raise Common::Exceptions::ResourceNotFound.new(detail: 'File no longer stored.')
      end
    end

    def self.attachments(parsed)
      attachment_keys = parsed.keys.select { |key| key.include? 'attachment' }
      parsed.slice(*attachment_keys).map { |k, v| { name: "#{k}.pdf", path: v.path } }
    end

    def self.write_json(guid, parsed)
      tempfile = Tempfile.new("#{guid}_metadata.json")
      tempfile.write(parsed['metadata'])
      tempfile.close
      tempfile
    end
  end
end
