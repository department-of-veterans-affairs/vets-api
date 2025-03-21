# frozen_string_literal: true

module Mobile
  module V1
    class LabOrTestSerializer
      include JSONAPI::Serializer

      def self.serialize(record)
        {
          id: record.id,
          type: record.type,
          attributes: serialize_attributes(record.attributes)
        }
      end

      def self.serialize_attributes(attributes)
        {
          display: attributes.display,
          test_code: attributes.test_code,
          date_completed: attributes.date_completed,
          sample_site: attributes.sample_site,
          encoded_data: attributes.encoded_data,
          location: attributes.location,
          ordered_by: attributes.ordered_by,
          observations: serialize_observations(attributes.observations)
        }
      end

      def self.serialize_observations(observations)
        observations.map do |obs|
          {
            test_code: obs.test_code,
            value_quantity: obs.value_quantity,
            reference_range: obs.reference_range,
            status: obs.status,
            comments: obs.comments
          }
        end
      end
    end
  end
end
