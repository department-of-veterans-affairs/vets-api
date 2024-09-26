# frozen_string_literal: true

module Preneeds
  # Models a {Preneeds::BurialForm} form attachment.
  # This is the data about the actual attachment, {Preneeds::Attachment}.
  #
  # @!attribute confirmation_code
  #   @return [String] guid of uploaded attachment
  # @!attribute attachment_id
  #   @return [String] attachment id
  # @!attribute name
  #   @return [String] attachment file name
  #
  class PreneedAttachmentHash < Preneeds::Base
    attribute :confirmation_code, String
    attribute :attachment_id, String
    attribute :name, String

    # (see Preneeds::Applicant.permitted_params)
    #
    def self.permitted_params
      %i[confirmation_code attachment_id name]
    end

    # @return [CarrierWave::Storage::AWSFile, CarrierWave::SanitizedFile] the previously uploaded file
    #
    def get_file
      ::Preneeds::PreneedAttachment.find_by(guid: confirmation_code).get_file
    end

    # @return [Preneeds::Attachment] the {Preneeds::Attachment} documented by this objects attributes
    #
    def to_attachment
      Preneeds::Attachment.new(
        attachment_type: AttachmentType.new(
          attachment_type_id: attachment_id
        ),
        file: get_file,
        name:
      )
    end
  end
end
