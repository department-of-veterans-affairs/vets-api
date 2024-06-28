# frozen_string_literal: true

module AsyncTransaction
  module Vet360
    class PermissionTransaction < AsyncTransaction::Vet360::Base
      def model_class
        "VAProfile::Models::Permission"
      end
    end
  end
end
