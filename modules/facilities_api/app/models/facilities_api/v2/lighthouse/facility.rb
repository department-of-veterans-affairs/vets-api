# frozen_string_literal: true

require 'vets/model'

module FacilitiesApi
  class V2::Lighthouse::Facility
    include Vets::Model

    attribute :access, Hash
    attribute :address, Hash
    attribute :classification, String
    attribute :distance, Float
    attribute :facility_type, String
    attribute :facility_type_prefix, String
    attribute :feedback, Hash
    attribute :hours, Hash
    attribute :id, String
    attribute :lat, Float
    attribute :long, Float
    attribute :mobile, Bool
    attribute :name, String
    attribute :operating_status, Hash
    attribute :operational_hours_special_instructions, String, array: true
    attribute :parent, Hash
    attribute :phone, Hash
    attribute :services, Hash
    attribute :time_zone, String
    attribute :type, String
    attribute :unique_id, String
    attribute :visn, String
    attribute :website, String
    attribute :tmp_covid_online_scheduling, Bool

    def initialize(fac)
      @id = fac['id']
      @facility_type_prefix, self.unique_id = fac['id'].split('_')
      @feedback = fac['attributes']['satisfaction']
      @type = fac['type']

      attributes = fac['attributes'].stringify_keys!.transform_keys!(&:underscore)

      super(attributes)
    end
  end
end
