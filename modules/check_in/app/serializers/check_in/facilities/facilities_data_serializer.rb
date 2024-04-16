# frozen_string_literal: true

module CheckIn
  module Facilities
    class FacilitiesDataSerializer
      include JSONAPI::Serializer

      set_id(&:id)

      attribute :name, if: proc { |facility|
        # attribute will not exist if no name field in facility data
        !facility[:name].nil?
      }

      attribute :type, if: proc { |facility|
        # attribute will not exist if no type field in facility data
        !facility[:type].nil?
      }

      attribute :classification, if: proc { |facility|
        # attribute will not exist if no classification field in facility data
        !facility[:classification].nil?
      }

      attribute :timezone, if: proc { |facility|
        # attribute will not exist if no timezone field in facility data
        !facility[:timezone].nil?
      }

      attribute :phone, if: proc { |facility|
        # attribute will not exist if no phone field in facility data
        !facility[:phone].nil?
      }

      attribute :physicalAddress, if: proc { |facility|
        # attribute will not exist if no name field in facility data
        !facility[:physicalAddress].nil?
      }
    end
  end
end
