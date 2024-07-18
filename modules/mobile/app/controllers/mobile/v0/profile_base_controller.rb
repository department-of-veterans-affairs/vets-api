# frozen_string_literal: true

require 'va_profile/address_validation/service'
require_relative '../concerns/sso_logging'

module Mobile
  module V0
    class ProfileBaseController < ApplicationController
      include Vet360::Writeable
      include Mobile::Concerns::SSOLogging

      before_action { authorize :vet360, :access? }
      after_action :invalidate_cache

      skip_after_action :invalidate_cache, only: [:validation]

      private

      def render_transaction_to_json(transaction)
        render json: AsyncTransaction::BaseSerializer.new(transaction).serializable_hash
      end

      def service
        Mobile::V0::Profile::SyncUpdateService.new(@current_user)
      end
    end
  end
end
