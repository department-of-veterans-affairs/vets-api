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
    d = diaries.select do |diary|
      diary[:diary_lc_status_type] == "PEND" && diary[:diary_reason_type] == "24"
    end

    d.any? do |eligible_diary_entry|
      eligible_diary_entry[:diary_due_date] < Time.now + 1.year
    end
  end

  def formatted_payload
    dependency_decs = object[:dependency_decs]
    ensured_array = dependency_decs.class == Hash ? [dependency_decs] : dependency_decs

    @formatted_payload ||= ensured_array.map { |hash| hash.except(:social_security_number) }
  end

  private

  def diaries
    object[:diaries].is_a?(Hash) ? [object[:diaries]] : object[:diaries]
  end
end
