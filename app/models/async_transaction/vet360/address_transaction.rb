# frozen_string_literal: true

module AsyncTransaction
  module Vet360
    class AddressTransaction < AsyncTransaction::Vet360::Base
      def model_class
        'VAProfile::Models::Address'
      end
    end
  end
end
