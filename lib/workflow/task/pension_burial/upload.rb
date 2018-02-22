# frozen_string_literal: true

module Workflow::Task::PensionBurial
  class Upload < Workflow::Task::ShrineFile::Base
    def upload_to_api
      service.upload(
        data.slice(:form_id, :code, :guid).merge(
          original_filename: @file.original_filename
        ),
        StringIO.new(@file.read),
        @file.mime_type
      )
    end

    def run(_options = {})
      persistent_attachment = PersistentAttachment.find(data[:id])

      if Settings.pension_burial&.upload&.enabled && persistent_attachment.can_upload_to_api?
        upload_to_api
      else
        path = File.join(Date.current.to_s, data[:form_id], data[:code])
        truncated_guid = data[:guid].split('-').first
        writer.write(@file.read, File.join(path, [truncated_guid, @file.original_filename].join('-')))
      end

      persistent_attachment.update(completed_at: Time.current)
    ensure
      writer.close
    end

    def writer
      @writer ||= SFTPWriter::Factory
                  .get_writer(Settings.pension_burial.sftp)
                  .new(Settings.pension_burial.sftp, logger: logger)
    end

    def service
      @service ||= ::PensionBurial::Service.new
    end
  end
end
