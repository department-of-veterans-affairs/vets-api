# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class Dependent < Common::Resource
      attribute :id, Types::String
      attribute :award_indicator, Types::String.optional.default(nil)
      attribute :date_of_birth, Types::String.optional.default(nil)
      attribute :email_address, Types::String.optional.default(nil)
      attribute :first_name, Types::String.optional.default(nil)
      attribute :last_name, Types::String.optional.default(nil)
      attribute :middle_name, Types::String.optional.default(nil)
      attribute :proof_of_dependency, Types::String.optional.default(nil)
      attribute :ptcpnt_id, Types::String.optional.default(nil)
      attribute :related_to_vet, Types::String.optional.default(nil)
      attribute :relationship, Types::String.optional.default(nil)
      attribute :veteran_indicator, Types::String.optional.default(nil)
    end
  end
end
