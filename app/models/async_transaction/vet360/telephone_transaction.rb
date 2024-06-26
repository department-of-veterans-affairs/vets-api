# frozen_string_literal: true

module AsyncTransaction
  module Vet360
    class TelephoneTransaction < AsyncTransaction::Vet360::Base
      def changed_field(*)
        'telephone'
      end
    end
  end
end
