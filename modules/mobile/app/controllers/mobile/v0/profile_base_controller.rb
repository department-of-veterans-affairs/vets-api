# frozen_string_literal: true

require_relative '../concerns/sso_logging'
require 'va_profile/address_validation/v3/service'

module Mobile
  module V0
    class ProfileBaseController < ApplicationController
      include Vet360::Writeable
      include Mobile::Concerns::SSOLogging

      before_action { authorize :vet360, :profile_access? }
      after_action :invalidate_cache

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
