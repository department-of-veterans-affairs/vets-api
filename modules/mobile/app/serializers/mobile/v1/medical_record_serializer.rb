# frozen_string_literal: true

module Mobile
  module V1
    class MedicalRecordSerializer
      include JSONAPI::Serializer

      def self.serialize(record)
        {
          id: record.id,
          type: record.type,
          attributes: {
            display: record.attributes.display,
            test_code: record.attributes.test_code,
            date_completed: record.attributes.date_completed,
            sample_site: record.attributes.sample_site,
            encoded_data: record.attributes.encoded_data,
            location: record.attributes.location,
            ordered_by: record.attributes.ordered_by,
            observations: record.attributes.observations.map do |obs|
              {
                test_code: obs.test_code,
                encoded_data: obs.encoded_data,
                value_quantity: obs.value_quantity,
                reference_range: obs.reference_range,
                status: obs.status,
                comments: obs.comments
              }
            end
          }
        }
      end
    end
  end
end
