# frozen_string_literal: true

require 'common/exceptions/validation_errors'
require 'evss/pciu/service'

module Mobile
  module V0
    class TransactionsController < ApplicationController
      include Vet360::Transactionable
      include Vet360::Writeable

      before_action { authorize :vet360, :access? }
      after_action :invalidate_cache

      def show
        check_transaction_status!
      rescue ActiveRecord::RecordNotFound
        raise Common::Exceptions::RecordNotFound, params[:transaction_id]
      end

      private

      def transaction_params
        params.permit :transaction_id
      end
    end
  end
end
