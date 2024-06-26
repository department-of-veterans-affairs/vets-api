# frozen_string_literal: true

module AsyncTransaction
  module Vet360
    class EmailTransaction < AsyncTransaction::Vet360::Base
      def changed_field(*)
        'email'
      end
    end
  end
end
