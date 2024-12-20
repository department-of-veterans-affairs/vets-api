# frozen_string_literal: true

require_relative 'address'
require_relative '../base'
require_relative '../email'
require_relative '../telephone'
require 'common/models/attribute_types/iso8601_time'

module VAProfile
  module Models
    module V3
      class Person < Base
        attribute :addresses, Array[Address]
        attribute :created_at, Common::ISO8601Time
        attribute :emails, Array[Email]
        attribute :source_date, Common::ISO8601Time
        attribute :telephones, Array[Telephone]
        attribute :transaction_id, String
        attribute :updated_at, Common::ISO8601Time
        attribute :vet360_id, String
        attribute :va_profile_id, String

        # Converts a decoded JSON response from VAProfile to an instance of the Person model
        # @param body [Hash] the decoded response body from VAProfile
        # @return [VAProfile::Models::Person] the model built from the response body
        def self.build_from(body)
          body ||= {}
          addresses = body['addresses']&.map { |a| VAProfile::Models::V3::Address.build_from(a) }
          emails = body['emails']&.map { |e| VAProfile::Models::Email.build_from(e) }
          telephones = body['telephones']&.map { |t| VAProfile::Models::Telephone.build_from(t) }

          VAProfile::Models::V3::Person.new(
            created_at: body['create_date'],
            source_date: body['source_date'],
            updated_at: body['update_date'],
            transaction_id: body['trx_audit_id'],
            addresses: addresses || [],
            emails: emails || [],
            telephones: telephones || [],
            vet360_id: body['vet360_id'] || body['va_profile_id'],
            va_profile_id: body['vet360_id'] || body['va_profile_id']
          )
        end
      end
    end
  end
end
