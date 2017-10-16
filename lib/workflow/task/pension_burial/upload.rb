# frozen_string_literal: true
module Workflow::Task::PensionBurial
  class Upload < Workflow::Task::ShrineFile::Base
    def run(_options = {})
      service.upload(
        data.slice(:form_id, :code, :guid).merge(
          original_filename: @file.original_filename
        ),
        @file.to_io,
        @file.mime_type
      )
      PersistentAttachment.find(data[:id]).update(completed_at: Time.current)
    end

    def service
      @service ||= ::PensionBurial::Service.new
    end
  end
end
