# frozen_string_literal: true

module VeteranConfirmation
  class VeteranStatusSerializer < ActiveModel::Serializer
    attributes :veteran_status
    type 'veteran_status_confirmations'

    def veteran_status
      object.veteran? ? 'confirmed' : 'not confirmed'
    end

    def id
      object.uuid
    end
  end
end
