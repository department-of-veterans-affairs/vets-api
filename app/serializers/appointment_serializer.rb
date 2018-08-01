# frozen_string_literal: true

class AppointmentSerializer < ActiveModel::Serializer
  attributes :appointments

  delegate :appointments, to: :object

  def id
    nil
  end
end
