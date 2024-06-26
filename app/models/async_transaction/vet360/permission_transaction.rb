# frozen_string_literal: true

module AsyncTransaction
  module Vet360
    class PermissionTransaction < AsyncTransaction::Vet360::Base
      def changed_field(*)
        'permission'
      end
    end
  end
end
