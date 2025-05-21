# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    module CheckIn
      class Contact < Common::Resource
        attribute :name, Types::String
        attribute :relationship, Types::String
        attribute :phone, Types::String
        attribute :workPhone, Types::String
        attribute :address, Address
        attribute :needsConfirmation, Types::Bool
      end
    end
  end
end
