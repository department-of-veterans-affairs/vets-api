# frozen_string_literal: true

class DependentsVerificationsSerializer < ActiveModel::Serializer
  type :dependency_decs

  attribute :dependency_verifications
  attribute :prompt_renewal

  def id
    nil
  end

  def dependency_verifications
    formatted_payload
  end

  def prompt_renewal
    formatted_payload.any? { |diary| diary[:award_effective_date] + 1.year > Date.current }
  end

  def formatted_payload
    dependency_decs = object[:dependency_decs]
    ensured_array = dependency_decs.class == Hash ? [dependency_decs] : dependency_decs

    @formatted_payload ||= ensured_array.map { |hash| hash.except(:social_security_number) }
  end
end
