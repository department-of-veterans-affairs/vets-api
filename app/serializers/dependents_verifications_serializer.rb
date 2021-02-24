# frozen_string_literal: true

class DependentsVerificationsSerializer < ActiveModel::Serializer
  type :dependency_decs

  attribute :dependency_verifications

  def id
    nil
  end

  def dependency_verifications
    formatted_payload(object[:dependency_decs])
  end

  def formatted_payload(dependency_decs)
    ensured_array = dependency_decs.class == Hash ? [dependency_decs] : dependency_decs

    ensured_array.map do |hash|
      hash.delete(:social_security_number)
      hash
    end
  end
end
