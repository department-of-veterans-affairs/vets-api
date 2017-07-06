# frozen_string_literal: true
module Preneeds
  class Attachment
    include Virtus.model

    attribute :attachment_type, Preneeds::AttachmentType
    attribute :description, String # name_of_the_file.pdf
    attribute :sending_name, String # name_of_the_file.pdf
    attribute :sending_source, String, default: 'vets.gov'

    attr_accessor :file, :tracking_number

    def message
      # TODO: do validations on the file type, file size, etc
      attachment = {
        attachment_type: {
          attachment_type_id: attachment_type.attachment_type_id,
          description: attachment_type.description
        }.compact,
        data_handler: id,
        description: description,
        sending_name: (sending_name || file.original_filename),
        sending_source: sending_source
      }.compact

      # This is necessary to make Attachment work as part of receiveApplication as well.
      if tracking_number.present?
        { tracking_number: tracking_number, pre_need_attachment: attachment }
      else
        attachment
      end
    end

    def id
      SecureRandom.base64(20)
    end

    def self.with_file(file, tracking_number: nil, attachment_type_id: 6)
      attributes = {
        attachment_type: { attachment_type_id: attachment_type_id },
        description: file.original_filename
      }
      attachment = new(attributes)
      attachment.tracking_number = tracking_number
      attachment.file = file
      attachment
    end
  end
end
