# frozen_string_literal: true

class AppealSeriesSerializer < ActiveModel::Serializer
  attribute :appeal_ids
  attribute :updated
  attribute :active
  attribute :incomplete_history
  attribute :aoj
  attribute :program_area
  attribute :description
  attribute :type
  attribute :aod
  attribute :location
  attribute :status
  attribute :alerts
  attribute :docket
  attribute :events
  attribute :evidence
  attribute :issues

  def id
    nil
  end
end
