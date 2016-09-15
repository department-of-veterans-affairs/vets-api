# frozen_string_literal: true
class ClaimBaseSerializer < ActiveModel::Serializer
  attributes :id, :date_filed, :min_est_date, :max_est_date,
             :tracked_items, :phase_dates, :open, :waiver_submitted
end
