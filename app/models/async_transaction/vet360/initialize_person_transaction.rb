# frozen_string_literal: true

module AsyncTransaction
  module Vet360
    class InitializePersonTransaction < AsyncTransaction::Vet360::Base
      def changed_field(*)
        'person'
      end
    end
  end
end
