# frozen_string_literal: true
class DisabilityClaimBaseSerializer < ActiveModel::Serializer
  attributes :id, :evss_id, :date_filed, :min_est_date, :max_est_date,
             :tracked_items, :phase_dates, :open, :waiver_submitted

  def date_filed
    object.data['date']
  end

  def min_est_date
    object.data['minEstClaimDate']
  end

  def max_est_date
    object.data['maxEstClaimDate']
  end

  def tracked_items
    object.data['claimTrackedItems']
  end

  def phase_dates
    object.data['claimPhaseDates']
  end

  def open
    object.data['claimCompleteDate'].blank?
  end

  def waiver_submitted
    object.data['waiver5103Submitted']
  end
end
