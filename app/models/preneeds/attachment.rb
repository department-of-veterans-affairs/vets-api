# frozen_string_literal: true
module Preneeds
  class Attachment
    include Virtus.model

    attribute :attachment_type, Preneeds::AttachmentType
    attribute :data_handler, String # CID:name_of_the_file.pdf
    attribute :description, String # name_of_the_file.pdf
    attribute :sending_name, String # name_of_the_file.pdf
    attribute :sending_source, String, default: 'vets.gov'

    attr_accessor :file

    def message
      # TODO: do validations on the file type, file size, etc
      {
        file: file, # this will be removed by the multipart_attachment middleware
        attachment_type: {
          attachment_type_id: attachment_type.attachment_type_id,
          description: attachment_type.description
        },
        data_handler: data_handler,
        description: description,
        sending_name: sending_name,
        sending_source: sending_source
      }
    end

    def self.with_file(file, attachment_type_id: 7)
      attributes = {
        attachment_type: { attachment_type_id: 7 },
        data_handler: "CID:#{file.original_filename}",
        description: file.original_filename
      }
      attachment = self.new(attributes)
      attachment.file = file
      attachment
    end
  end
end
