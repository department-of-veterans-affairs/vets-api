# frozen_string_literal: true

module Appeals
  module Models
    class Appeal
      include Virtus.model(nullify_blank: true)

      attribute :appeal_ids, Array
      attribute :updated, Date
      attribute :active, Boolean
      attribute :incomplete_history, Boolean
      attribute :aoj,	String
      attribute :program_area, String
      attribute :description,	String
      attribute :type, String
      attribute :aod,	Boolean
      attribute :location, String
      attribute :status, Hash
      attribute :alerts, Array[Alert]
      attribute :docket, Docket
      attribute :events, Array[Event]
      attribute :evidence, Array[Evidence]
      attribute :issues, Array[Issue]

      def initialize(appeal)
        super(appeal.dig('attributes'))
      end
    end
  end
end
