# frozen_string_literal: true

module AsyncTransaction
  module Vet360
    class Base < AsyncTransaction::Base
      SENT = 'sent'
      def self.start(user, response)
        create(
          user_uuid: user.uuid,
          source_id: user.vet360_id,
          source: 'vet360',
          status: SENT,
          transaction_id: response.transaction.id,
          transaction_status: response.transaction.status
        )
      end
    end
  end
end
