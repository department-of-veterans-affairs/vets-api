# frozen_string_literal: true

require 'common/models/base'

# POA model
class Poa < Common::Base
  attribute :social_security_number
  attribute :code
  attribute :name
  attribute :organization
end
