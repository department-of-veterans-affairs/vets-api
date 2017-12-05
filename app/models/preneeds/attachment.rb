# frozen_string_literal: true
module Preneeds
  class Attachment
    include Virtus.model
    VETS_GOV = 'vets.gov'

    attribute :attachment_type, Preneeds::AttachmentType
    attribute :sending_source, String, default: VETS_GOV
    attribute :file, (Rails.env.production? ? CarrierWave::Storage::AWSFile : CarrierWave::SanitizedFile)

    attr_reader :data_handler

    def initialize(*args)
      super
      @data_handler = SecureRandom.hex
    end

    def as_eoas
      {
        attachmentType: {
          attachmentTypeId: attachment_type.attachment_type_id
        },
        dataHandler: {
          'inc:Include': '',
          attributes!: {
            'inc:Include': {
              href: "cid:#{@data_handler}",
              'xmlns:inc': 'http://www.w3.org/2004/08/xop/include'
            }
          }
        },
        description: file.filename,
        sendingName: VETS_GOV,
        sendingSource: sending_source
      }
    end
  end
end
