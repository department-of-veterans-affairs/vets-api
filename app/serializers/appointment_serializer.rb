# frozen_string_literal: true

class AppointmentSerializer < ActiveModel::Serializer
  attributes :appointments

  # Returns an array of the veteran's appointments data.
  #
  # @return [Array]
  #
  delegate :appointments, to: :object

  def id
    nil
  end
end
