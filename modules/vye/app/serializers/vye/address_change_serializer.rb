# frozen_string_literal: true

module Vye
  class AddressChangeSerializer
    def initialize(resource)
      @resource = resource
    end

    def to_json(*)
      Oj.dump(serializable_hash, mode: :compat, time_format: :ruby)
    end

    def serializable_hash
      {
        veteran_name: @resource.veteran_name,
        address1: @resource.address1,
        address2: @resource.address2,
        address3: @resource.address3,
        address4: @resource.address4,
        address5: @resource.address5,
        city: @resource.city,
        state: @resource.state,
        zip_code: @resource.zip_code,
        origin: @resource.origin
      }
    end
  end
end
