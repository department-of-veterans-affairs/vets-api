# frozen_string_literal: true

module AsyncTransaction
  module Vet360
    class InitializePersonTransaction < AsyncTransaction::Vet360::Base
      def model_class
        'VAProfile::Models::Person'
      end
    end
  end
end
