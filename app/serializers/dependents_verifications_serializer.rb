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
    diary_entries.any? do |diary_entry|
      diary_entry[:diary_lc_status_type] == 'PEND' &&
        diary_entry[:diary_reason_type] == '24' &&
        diary_entry[:diary_due_date] < Time.zone.now + 7.years
    end
  end

  private

  def formatted_payload
    dependency_decs = object[:dependency_decs]
    ensured_array = dependency_decs.instance_of?(Hash) ? [dependency_decs] : dependency_decs

    @formatted_payload ||= ensured_array.map { |hash| hash.except(:social_security_number) }
  end

  def diary_entries
    object[:diaries].is_a?(Hash) ? [object[:diaries]] : object[:diaries]
  end
end
