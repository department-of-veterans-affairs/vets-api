# frozen_string_literal: true

module AsyncTransaction
  module Vet360
    class TelephoneTransaction < AsyncTransaction::Vet360::Base
      def model_class
        "VAProfile::Models::Telephone"
      end
    end
  end
end
