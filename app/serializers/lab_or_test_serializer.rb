# frozen_string_literal: true

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
      sample_tested: attributes.sample_tested,
      encoded_data: attributes.encoded_data,
      location: attributes.location,
      ordered_by: attributes.ordered_by,
      body_site: attributes.body_site,
      observations: serialize_observations(attributes.observations)
    }
  end

  def self.serialize_observations(observations)
    observations.map do |obs|
      {
        test_code: obs.test_code,
        value: serialize_value(obs.value),
        reference_range: obs.reference_range,
        status: obs.status,
        comments: obs.comments,
        body_site: obs.body_site,
        sample_tested: obs.sample_tested
      }
    end
  end

  def self.serialize_value(value)
    {
      text: value.text,
      type: value.type
    }
  end
end
