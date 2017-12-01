# frozen_string_literal: true
module Preneeds
  class PreneedAttachmentHash < Preneeds::Base
    attribute :confirmation_code, String
    attribute :attachment_id, String

    def self.permitted_params
      [:confirmation_code, :attachment_id]
    end

    def get_file
      ::Preneeds::PreneedAttachment.find_by(guid: confirmation_code).get_file
    end

    def to_attachment
      Attachment.new(
        attachment_type: AttachmentType.new(
          attachment_type_id: attachment_id
        ),
        file: get_file
      )
    end
  end
end
