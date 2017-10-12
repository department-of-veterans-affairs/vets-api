# frozen_string_literal: true
module Workflow::Task::PensionBurial
  class Upload < Workflow::Task::ShrineFile::Base
    def run(_options = {})
      path = File.join(Date.current.to_s, data[:form_id], data[:code])
      truncated_guid = data[:guid].split('-').first
      writer.write(@file.read, File.join(path, [truncated_guid, @file.original_filename].join('-')))
      PersistentAttachment.find(data[:id]).update(completed_at: Time.current)
    ensure
      writer.close
    end

    def writer
      @writer ||= SFTPWriter::Factory
                  .get_writer(Settings.pension_burial.sftp)
                  .new(Settings.pension_burial.sftp, logger: logger)
    end
  end
end
