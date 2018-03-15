# frozen_string_literal: true

module Appeals
  module Models
    class AppealSeries
      include Virtus.model(nullify_blank: true)

      attribute :id, String
      attribute :appeal_ids, Array
      attribute :active, Boolean
      attribute :alerts, Array[Alert]
      attribute :aod,	Boolean
      attribute :aoj,	String
      attribute :description,	String
      attribute :docket, Docket
      attribute :events, Array[Event]
      attribute :evidence, Array[Evidence]
      attribute :incomplete_history, Boolean
      attribute :issues, Array[Issue]
      attribute :location, String
      attribute :program_area, String
      attribute :type, String
      attribute :status, Hash
      attribute :updated, Date
    end
  end
end
