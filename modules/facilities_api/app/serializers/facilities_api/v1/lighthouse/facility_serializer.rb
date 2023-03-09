# frozen_string_literal: true

module FacilitiesApi
  class V1::Lighthouse::FacilitySerializer
    include JSONAPI::Serializer

    set_key_transform :camel_lower

    attribute :access do |obj|
      obj.access&.deep_stringify_keys&.deep_transform_keys { |key| key.camelize(:lower) }
    end
    attribute :active_status
    attribute :address do |obj|
      obj.address&.deep_stringify_keys&.deep_transform_keys { |key| key.camelize(:lower) }
    end
    attribute :classification
    attribute :detailed_services do |obj|
      obj.detailed_services&.collect do |ds|
        ds&.deep_stringify_keys&.deep_transform_keys do |key|
          key.camelize(:lower)
        end
      end
    end
    attribute :distance
    attribute :facility_type
    attribute :feedback do |obj|
      obj.feedback&.deep_stringify_keys&.deep_transform_keys { |key| key.camelize(:lower) }
    end
    attribute :hours do |obj|
      obj.hours&.deep_stringify_keys&.deep_transform_keys { |key| key.camelize(:lower) }
    end
    attribute :id
    attribute :lat
    attribute :long
    attribute :mobile
    attribute :name
    attribute :operating_status do |obj|
      obj.operating_status&.deep_stringify_keys&.deep_transform_keys { |key| key.camelize(:lower) }
    end
    attribute :operational_hours_special_instructions
    attribute :phone do |obj|
      obj.phone&.deep_stringify_keys&.deep_transform_keys { |key| key.camelize(:lower) }
    end
    attribute :services do |obj|
      obj.services&.deep_stringify_keys&.deep_transform_keys { |key| key.camelize(:lower) }
    end
    attribute :unique_id
    attribute :visn
    attribute :website
    attribute :tmp_covid_online_scheduling
  end
end
