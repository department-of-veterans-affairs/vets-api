# frozen_string_literal: true

require 'va_profile/response'
require 'va_profile/models/associated_person'
require 'va_profile/models/message'
require 'va_profile/models/preferred_name'
require 'common/models/attribute_types/titlecase_string'

module VAProfile::Profile::V3
  class GenderIdentityTraitsBioResponse < VAProfile::Response
    attr_reader :body

    attribute :messages, Array[VAProfile::Models::Message]
    attribute :preferred_name, Common::TitlecaseString

    def initialize(response)
      @body = response.body
      messages = body['messages']
      preferred_name = body.dig('profile', 'gender_identity_traits', 'preferred_name', 'preferred_name')
      super(response.status, { messages:, preferred_name: })
    end

    def metadata
      { status:, messages: }
    end
  end
end
