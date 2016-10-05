# frozen_string_literal: true
class DisabilityClaimBaseSerializer < ActiveModel::Serializer
  attributes :id, :evss_id, :date_filed, :min_est_date, :max_est_date,
             :phase_change_date, :open, :waiver_submitted

  def date_filed
    date_from_string 'date'
  end

  def min_est_date
    date_from_string 'minEstClaimDate'
  end

  def max_est_date
    date_from_string 'maxEstClaimDate'
  end

  def phase_change_date
    date_from_string 'claimPhaseDates', 'phaseChangeDate'
  end

  def open
    object.data['claimCompleteDate'].blank?
  end

  def waiver_submitted
    object.data['waiver5103Submitted']
  end

  protected

  def with_object_data(*keys)
    val = object.data.dig(*keys)
    yield val if val.present?
  end

  def list_objects_with_key(parents, sub_keys)
    parent = object.data.dig(*parents)
    parent = [] if parent.blank?
    parent.each do |obj|
      val = obj.dig(*sub_keys)
      obj if val.present?
    end.compact
  end

  def bool_from_yes_no(*keys)
    with_object_data(*keys) do |s|
      case s.downcase
      when 'yes' then true
      when 'no' then false
        # TODO: Log weird input
      end
    end
  end

  def date_from_string(*keys, format: '%m/%d/%Y')
    with_object_data(*keys) do |s|
      Date.strptime(s, format)
    end
  end
end
