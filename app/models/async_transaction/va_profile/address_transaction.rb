# frozen_string_literal: true

module AsyncTransaction
  module VAProfile
    class AddressTransaction < AsyncTransaction::VAProfile::Base
      def send_notifications?
        true
      end
    end
  end
end
