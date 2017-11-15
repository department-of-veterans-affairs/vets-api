# frozen_string_literal: true
module Preneeds
  class Attachment
    include Virtus.model

    attribute :attachment_type, Preneeds::AttachmentType
    attribute :sending_source, String, default: 'vets.gov'
    attribute :file, (Rails.env.production? ? CarrierWave::Storage::AWSFile : CarrierWave::SanitizedFile)

    attr_accessor :file, :tracking_number

    def as_eoas
      {
        attachmentType: {
          attachmentTypeId: attachment_type.attachment_type_id
        }.compact,
        dataHandler: id,
        description: file.filename
        sendingSource: sending_source
      }.compact
    end

    def id
      SecureRandom.uuid
    end
  end
end
