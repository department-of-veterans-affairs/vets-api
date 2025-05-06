# frozen_string_literal: true

class DependentsVerificationsSerializer
  include JSONAPI::Serializer

  set_id { '' }
  set_type :dependency_decs

  attribute :dependency_verifications

  attribute :dependency_verifications do |object|
    dependency_decs = object[:dependency_decs]
    ensured_array = dependency_decs.instance_of?(Hash) ? [dependency_decs] : dependency_decs

    ensured_array.map { |hash| hash.except(:social_security_number) }
  end

  attribute :prompt_renewal do |object|
    diaries = object[:diaries]
    diary_entries = diaries.is_a?(Hash) ? [diaries] : diaries

    diary_entries.any? do |diary_entry|
      diary_entry[:diary_lc_status_type] == 'PEND' &&
        diary_entry[:diary_reason_type] == '24' &&
        diary_entry[:diary_due_date] < 7.years.from_now
    end
  end
end
