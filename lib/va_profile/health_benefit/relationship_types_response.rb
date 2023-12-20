# frozen_string_literal: true

require 'va_profile/response'
require 'va_profile/models/relationship_type'
require 'va_profile/models/message'

module VAProfile
  module HealthBenefit
    class RelationshipTypes < VAProfile::Response
      attribute :relationship_types, Array[VAProfile::Models::RelationshipType]
      attribute :messages, Array[VAProfile::Models::Message]

      def initialize(status_code, data)
        super(status_code)
        self.relationship_types = data[:relationship_types]
        self.messages = data[:messages]
      end

      class << self
        def from(response)
          status_code = response.status
          json = JSON.parse(response.body)
          relationship_types = json['relationship_types']
                               &.map { |r| VAProfile::Models::RelationshipType.build_from(r) }
          messages = json['messages']
                     &.map { |m| VAProfile::Models::Message.build_from(m) }
          new(status_code, { messages:, relationship_types: })
        end
      end
    end
  end
end
