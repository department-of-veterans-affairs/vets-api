# frozen_string_literal: true

class DismissedStatusSerializer < ActiveModel::Serializer
  attribute :subject
  attribute :dismissed_status
  attribute :status_effective_at
  attribute :dismissed_at

  def id
    nil
  end

  def dismissed_status
    object.status
  end

  # Converts status_effective_at into desired datetime string format.
  #
  # @see https://api.rubyonrails.org/classes/ActiveSupport/TimeWithZone.html#method-i-as_json
  #
  def status_effective_at
    object.status_effective_at.as_json
  end

  def dismissed_at
    object.read_at.as_json
  end
end
