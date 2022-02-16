# frozen_string_literal: true

require 'common/models/base'

class PaymentHistory < Common::Base
  attribute :payments, Array
  attribute :return_payments, Array
end
