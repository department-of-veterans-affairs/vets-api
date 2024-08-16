# frozen_string_literal: true

module AsyncTransaction
  module VAProfile
    class TelephoneTransaction < AsyncTransaction::VAProfile::Base
      def send_change_notifications?
        true
      end
    end
  end
end
