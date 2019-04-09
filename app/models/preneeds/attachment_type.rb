# frozen_string_literal: true

require 'common/models/base'

module Preneeds
  # Models an attachment type from the EOAS service.
  # For use within the {Preneeds::BurialForm} form.
  #
  # @!attribute attachment_type_id
  #   @return [Integer] attachment type id
  # @!attribute description
  #   @return [String] attachment type description
  #
  class AttachmentType < Common::Base
    attribute :attachment_type_id, Integer
    attribute :description, String

    # Alias for :attachment_type_id attribute
    #
    # @return [Integer] attachment type id
    #
    def id
      attachment_type_id
    end

    # Sort operator
    # Default sort should be by description ascending
    #
    # @return [Integer] -1, 0, or 1
    #
    def <=>(other)
      description <=> other.description
    end
  end
end
