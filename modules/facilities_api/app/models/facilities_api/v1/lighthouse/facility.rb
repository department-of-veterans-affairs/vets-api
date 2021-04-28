# frozen_string_literal: true

require 'common/models/base'
# Facility Model
module FacilitiesApi
  class V1::Lighthouse::Facility < Common::Base
    include ActiveModel::Serializers::JSON

    attribute :access, Object
    attribute :active_status, String
    attribute :address, Object
    attribute :classification, String
    attribute :detailed_services, Object
    attribute :distance, Float
    attribute :facility_type, String
    attribute :facility_type_prefix, String
    attribute :feedback, Object
    attribute :hours, Object
    attribute :id, String
    attribute :lat, Float
    attribute :long, Float
    attribute :mobile, Boolean
    attribute :name, String
    attribute :operating_status, Object
    attribute :operational_hours_special_instructions, String
    attribute :phone, Object
    attribute :services, Object
    attribute :type, String
    attribute :unique_id, String
    attribute :visn, String
    attribute :website, String

    def initialize(fac)
      super(fac)
      set_attributes(fac)

      self.id = fac['id']
      self.type = fac['type']
      self.feedback = fac['attributes']['satisfaction']
      self.access = fac['attributes']['wait_times']
      self.facility_type_prefix, self.unique_id = fac['id'].split('_')
    end

    private

    def set_attributes(fac)
      fac['attributes'].each_key do |key|
        self[key] = fac['attributes'][key] if attributes.include?(key.to_sym)
      end
    end
  end
end
