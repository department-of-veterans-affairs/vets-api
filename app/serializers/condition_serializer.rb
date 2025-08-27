# frozen_string_literal: true

class ConditionSerializer
  include JSONAPI::Serializer

  def self.serialize(record)
    {
      id: record.id,
      type: record.type,
      attributes: serialize_attributes(record.attributes)
    }
  end

  def self.serialize_attributes(attributes)
    {
      date: attributes.date,
      name: attributes.name,
      provider: attributes.provider,
      facility: attributes.facility,
      comments: attributes.comments
    }
  end
end
