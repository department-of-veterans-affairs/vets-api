# frozen_string_literal: true

module VIC
  class AttachmentUploadJob
    include Sidekiq::Worker

    def perform(case_id, form)
      Raven.tags_context(backend_service: :vic)
      parsed_form = JSON.parse(form)
      vic_service = Service.new
      vic_service.send_files(case_id, parsed_form)
    end
  end
end
