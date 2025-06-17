# frozen_string_literal: true

require 'vets/model'

module Preneeds
  # Models an attachment type from the EOAS service.
  # For use within the {Preneeds::BurialForm} form.
  #
  # @!attribute attachment_type_id
  #   @return [Integer] attachment type id
  # @!attribute description
  #   @return [String] attachment type description
  #
  class AttachmentType
    include Vets::Model

    attribute :attachment_type_id, Integer
    attribute :description, String

    default_sort_by description: :asc

    # Alias for :attachment_type_id attribute
    #
    # @return [Integer] attachment type id
    #
    def id
      attachment_type_id
    end
  end
end
