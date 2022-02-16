# frozen_string_literal: true

class OnsiteNotificationSerializer < ActiveModel::Serializer
  def attributes(...)
    object.attributes.symbolize_keys
  end
end
