# frozen_string_literal: true

class ServiceInformationSerializer < ActiveModel::Serializer
  attribute :service_periods
  attribute :served_in_combat_zone

  def id
    nil
  end

  def service_periods
    object[:service_periods]
  end

  def served_in_combat_zone
    object[:served_in_combat_zone]
  end
end
