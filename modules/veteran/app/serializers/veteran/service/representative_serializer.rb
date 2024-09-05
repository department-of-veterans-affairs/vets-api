# frozen_string_literal: true

module Veteran
  module Service
    class RepresentativeSerializer
      include JSONAPI::Serializer

      attributes :first_name, :last_name, :poa_codes
    end
  end
end
