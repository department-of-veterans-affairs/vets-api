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
        fac['attributes'].each_key do |key|
          self[key] = fac['attributes'][key] if attributes.include?(key.to_sym)
        end

        self.id = fac['id']
        self.type = fac['type']
        self.feedback = fac['attributes']['satisfaction']
        self.access = fac['attributes']['wait_times']
        self.facility_type_prefix, self.unique_id = fac['id'].split('_')
      end
    end
  end
end
