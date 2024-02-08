# frozen_string_literal: true

require 'va_profile/response'
require 'va_profile/models/associated_person'
require 'va_profile/models/message'

module VAProfile::Profile::V3
  class HealthBenefitBioResponse < VAProfile::Response
    attribute :body, Hash
    attribute :contacts, Array[VAProfile::Models::AssociatedPerson]
    attribute :messages, Array[VAProfile::Models::Message]

    def initialize(response)
      attributes = {
        body: response.body,
        contacts: response.body.dig('profile', 'health_benefit', 'associated_persons'),
        messages: response.body['messages']
      }
      super(response.status, attributes)
    end
  end
end
