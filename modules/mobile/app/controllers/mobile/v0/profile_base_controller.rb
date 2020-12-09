# frozen_string_literal: true

require_dependency 'mobile/application_controller'
require 'vet360/address_validation/service'

module Mobile
  module V0
    class ProfileBaseController < ApplicationController
      include Vet360::Writeable

      before_action { authorize :vet360, :access? }
      after_action :invalidate_cache

      skip_after_action :invalidate_cache, only: [:validation]

      private

      def render_transaction_to_json(transaction)
        render json: transaction, serializer: AsyncTransaction::BaseSerializer
      end

      def service
        Mobile::V0::Profile::SyncUpdateService.new(@current_user)
      end
    end
  end
end
