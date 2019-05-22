# frozen_string_literal: true

class DismissedStatusSerializer < ActiveModel::Serializer
  attribute :subject
  attribute :status
  attribute :status_effective_at
  attribute :read_at

  def id
    nil
  end

  # Converts status_effective_at into desired datetime string format.
  #
  # @see https://api.rubyonrails.org/classes/ActiveSupport/TimeWithZone.html#method-i-as_json
  #
  def status_effective_at
    object.status_effective_at.as_json
  end

  def read_at
    object.read_at.as_json
  end
end
