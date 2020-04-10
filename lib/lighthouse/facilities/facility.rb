# frozen_string_literal: true

require 'common/models/base'
# Facility Model
module Lighthouse
  module Facilities
    class Facility < Common::Base
      attribute :id, String
      attribute :type, String
      attribute :name, String
      attribute :facility_type, String
      attribute :classification, String
      attribute :website, String
      attribute :lat, Float
      attribute :long, Float
      attribute :address, Object
      attribute :phone, Object
      attribute :hours, Object
      attribute :services, Object
      attribute :feedback, Object
      attribute :access, Object
      attribute :mobile, Boolean
      attribute :active_status, String
      attribute :visn, String
      attribute :operating_status, Object
      attribute :facility_type_prefix, String
      attribute :unique_id, String

      def initialize(fac)
        self.id = fac['id']
        self.type = fac['type']
        self.name = fac['attributes']['name']
        self.facility_type = fac['attributes']['facility_type']
        self.classification = fac['attributes']['classification']
        self.website = fac['attributes']['website']
        self.lat = fac['attributes']['lat']
        self.long = fac['attributes']['long']
        self.address = fac['attributes']['address']
        self.phone = fac['attributes']['phone']
        self.hours = fac['attributes']['hours']
        self.services = fac['attributes']['services']
        self.feedback = fac['attributes']['satisfaction']
        self.access = fac['attributes']['wait_times']
        self.mobile = fac['attributes']['mobile']
        self.active_status = fac['attributes']['active_status']
        self.visn = fac['attributes']['visn']
        self.operating_status = fac['attributes']['operating_status']
        self.facility_type_prefix, self.unique_id = fac['id'].split('_')
      end
    end
  end
end
