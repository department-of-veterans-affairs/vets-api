# frozen_string_literal: true

require 'vets/model'

# PowerOfAttorney model
class PowerOfAttorney
  include Vets::Model

  attribute :social_security_number, String
  attribute :code, String
  attribute :name, String
  attribute :organization, String
  attribute :begin_date, String
end
