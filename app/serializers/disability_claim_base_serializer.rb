# frozen_string_literal: true
class DisabilityClaimBaseSerializer < ActiveModel::Serializer
  attributes :id, :evss_id, :date_filed, :min_est_date, :max_est_date,
             :tracked_items, :phase_change_date, :open, :waiver_submitted

  def date_filed
    date_from_string 'date'
  end

  def min_est_date
    date_from_string 'minEstClaimDate'
  end

  def max_est_date
    date_from_string 'maxEstClaimDate'
  end

  def tracked_items
    object.data['claimTrackedItems']
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
    if val.present?
      yield val
    end
  end

  def date_from_string(*keys, format: '%m/%d/%Y')
    with_object_data(*keys) do |s|
      Date.strptime(s, format)
    end
  end

  # For date-times recording a computer event and therefore known to the
  # second EVSS uses a UNIX timestamp in milliseconds. It is mostly for
  # intent to file and documents.
  def date_from_unix_milliseconds(*keys)
    with_object_data(*keys) do |s|
      Time.at(s.to_i / 1000).utc.to_date
    end
  end
end
