# frozen_string_literal: true

class NotificationSerializer < ActiveModel::Serializer
  attribute :subject
  attribute :read_at

  def id
    nil
  end

  # Converts status_effective_at into desired datetime string format.
  #
  # @see https://api.rubyonrails.org/classes/ActiveSupport/TimeWithZone.html#method-i-as_json
  #
  def read_at
    object.read_at.as_json
  end
end
