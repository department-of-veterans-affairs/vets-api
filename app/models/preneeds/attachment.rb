# frozen_string_literal: true
module Preneeds
  class Attachment
    include Virtus.model

    attribute :attachment_type, Preneeds::AttachmentType
    attribute :sending_source, String, default: 'vets.gov'
    attribute :file, (Rails.env.production? ? CarrierWave::Storage::AWSFile : CarrierWave::SanitizedFile)

    attr_reader :data_handler

    def initialize(*args)
      super
      @data_handler = "#{SecureRandom.hex}.pdf"
    end

    def as_eoas
      {
        attachmentType: {
          attachmentTypeId: attachment_type.attachment_type_id
        }.compact,
        dataHandler: "cid:#{@data_handler}",
        description: @data_handler,
        sendingName: @data_handler,
        sendingSource: sending_source
      }.compact
    end
  end
end
