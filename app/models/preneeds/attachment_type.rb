# frozen_string_literal: true

require 'common/models/base'

# DischargeType model
module Preneeds
  class AttachmentType < Common::Base
    attribute :attachment_type_id, Integer
    attribute :description, String

    def id
      attachment_type_id
    end

    # Default sort should be by name ascending
    def <=>(other)
      description <=> other.description
    end
  end
end
