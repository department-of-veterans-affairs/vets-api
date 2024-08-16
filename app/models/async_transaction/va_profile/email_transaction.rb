# frozen_string_literal: true

module AsyncTransaction
  module VAProfile
    class EmailTransaction < AsyncTransaction::VAProfile::Base
      def send_change_notifications?
        true
      end
    end
  end
end
