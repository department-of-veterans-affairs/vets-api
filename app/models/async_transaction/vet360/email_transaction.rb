# frozen_string_literal: true

module AsyncTransaction
  module Vet360
    class EmailTransaction < AsyncTransaction::Vet360::Base
      def model_class
        'VAProfile::Models::Email'
      end
    end
  end
end
