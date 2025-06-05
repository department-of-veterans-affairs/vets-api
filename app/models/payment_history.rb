# frozen_string_literal: true

require 'vets/model'

class PaymentHistory
  include Vets::Model

  attribute :payments, Hash, array: true
  attribute :return_payments, Hash, array: true
end
