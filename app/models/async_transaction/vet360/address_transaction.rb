# frozen_string_literal: true

module AsyncTransaction
  module Vet360
    class AddressTransaction < AsyncTransaction::Vet360::Base
      def changed_field(*)
        'address'
      end
    end
  end
end
