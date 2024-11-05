# frozen_string_literal: true

module FacilitiesApi
  class V2::Lighthouse::FacilitySerializer
    include JSONAPI::Serializer

    set_key_transform :camel_lower

    attributes :classification, :distance, :facility_type, :id, :lat, :long, :mobile, :name,
               :operational_hours_special_instructions, :unique_id, :visn, :website, :tmp_covid_online_scheduling
    attribute :access do |obj|
      obj.access&.deep_stringify_keys&.deep_transform_keys do |key|
        key.camelize(:lower)
      end || { 'health' => [], 'effectiveDate' => '' }
    end
    attribute :address do |obj|
      obj.address&.deep_stringify_keys&.deep_transform_keys { |key| key.camelize(:lower) } || []
    end
    attribute :feedback do |obj|
      obj.feedback&.deep_stringify_keys&.deep_transform_keys { |key| key.camelize(:lower) } || []
    end
    attribute :hours do |obj|
      obj.hours&.deep_stringify_keys&.deep_transform_keys { |key| key.camelize(:lower) } || []
    end
    attribute :operating_status do |obj|
      obj.operating_status&.deep_stringify_keys&.deep_transform_keys { |key| key.camelize(:lower) } || []
    end
    attribute :phone do |obj|
      obj.phone&.deep_stringify_keys&.deep_transform_keys { |key| key.camelize(:lower) } || []
    end
    attribute :services do |obj|
      obj.services&.deep_stringify_keys&.deep_transform_keys { |key| key.camelize(:lower) } || []
    end
  end
end
