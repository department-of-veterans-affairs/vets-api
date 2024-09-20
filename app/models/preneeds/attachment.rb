# frozen_string_literal: true

module Preneeds
  # Models a {Preneeds::BurialForm} form attachment
  #
  # @!attribute attachment_type
  #   @return [Preneeds::AttachmentType] {Preneeds::AttachmentType} object
  # @!attribute sending_source
  #   @return [String] sending source; currently hard coded
  # @!attribute file
  #   @return [CarrierWave::Storage::AWSFile, CarrierWave::SanitizedFile]
  # @!attribute name
  #   @return [String] attachment name
  # @!attribute data_handler
  #   @return [String] auto-generated attachment id
  #
  class Attachment < Preneeds::Base
    # string to populate #sending_source
    #
    VETS_GOV = 'vets.gov'

    attr_accessor :attachment_type, :sending_source, :file, :name
    attr_reader :data_handler

    # Creates a new instance of {Preneeds::Attachment}
    #
    # @param args [Hash] hash with keys that correspond to attributes
    #
    def initialize(attributes = {})
      super
      @sending_source ||= VETS_GOV
      @file = file_class.new(attributes[:file]) if attributes[:file]
      @data_handler = SecureRandom.hex
    end

    # (see Preneeds::BurialForm#as_eoas)
    #
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
        description: name,
        sendingName: VETS_GOV,
        sendingSource: sending_source
      }
    end

    private

    def file_class
      Rails.env.production? ? CarrierWave::Storage::AWSFile : CarrierWave::SanitizedFile
    end
  end
end
