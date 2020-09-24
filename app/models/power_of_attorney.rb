# frozen_string_literal: true

require 'common/models/base'

# PowerOfAttorney model
class PowerOfAttorney < Common::Base
  attribute :social_security_number
  attribute :code
  attribute :name
  attribute :organization
end
