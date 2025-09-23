# frozen_string_literal: true

require 'vets/model'

# Facility Model
module Lighthouse
  module Facilities
    class Facility
      include Vets::Model

      attribute :access, Hash
      attribute :active_status, String
      attribute :address, Hash
      attribute :classification, String
      attribute :detailed_services, Hash
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
      attribute :operational_hours_special_instructions, String
      attribute :phone, Hash
      attribute :services, Hash
      attribute :type, String
      attribute :unique_id, String
      attribute :visn, String
      attribute :website, String
      attribute :parent, Hash

      alias mobile? mobile

      def initialize(fac)
        @id = fac['id']
        @type = fac['type']
        @feedback = fac['attributes']['satisfaction']
        @access = fac['attributes']['wait_times']
        @facility_type_prefix, @unique_id = fac['id'].split('_')

        super(fac['attributes'])
      end
    end
  end
end
