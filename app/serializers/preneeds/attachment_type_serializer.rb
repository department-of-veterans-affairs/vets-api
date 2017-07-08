# frozen_string_literal: true
module Preneeds
  class AttachmentTypeSerializer < ActiveModel::Serializer
    attribute :id

    attribute(:attachment_type_id) { object.id }
    attribute :description
  end
end
