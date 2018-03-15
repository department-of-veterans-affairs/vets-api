# frozen_string_literal: true

module Appeals
  module Models
    class AppealSeriesSerializer
      include JSONAPI::Serializer

      attribute :appeal_ids
      attribute :active
      attribute :alerts
      attribute :aod
      attribute :aoj
      attribute :description
      attribute :docket
      attribute :events
      attribute :evidence
      attribute :incomplete_history
      attribute :issues
      attribute :location
      attribute :program_area
      attribute :type
      attribute :status
      attribute :updated

      def format_name(attribute_name)
        attribute_name.to_s
      end
    end
  end
end
