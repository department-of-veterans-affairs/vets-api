# frozen_string_literal: true

require 'common/models/base'

module FacilitiesApi
  class V2::Lighthouse::Facility < Common::Base
    include ActiveModel::Serializers::JSON
    attribute :access, Object
    attribute :address, Object
    attribute :classification, String
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
    attribute :operational_hours_special_instructions, Object
    attribute :parent, Object
    attribute :phone, Object
    attribute :services, Object
    attribute :time_zone, String
    attribute :type, String
    attribute :unique_id, String
    attribute :visn, String
    attribute :website, String
    attribute :tmp_covid_online_scheduling, Boolean

    def initialize(fac)
      super(fac)
      set_attributes(fac)

      self.id = fac['id']
      self.facility_type_prefix, self.unique_id = fac['id'].split('_')
      self.feedback = fac['attributes']['satisfaction']
      self.type = fac['type']
    end

    private

    def set_attributes(fac)
      fac['attributes'].each_key do |key|
        self[key.underscore] = fac['attributes'][key] if attributes.include?(key.underscore.to_sym)
      end
    end
  end
end
