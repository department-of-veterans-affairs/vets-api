# frozen_string_literal: true

module V0
  module Profile
    class PersonsController < ApplicationController
      after_action :invalidate_mvi_cache

      def initialize_vet360_id
        response    = Vet360::Person::Service.new(@current_user).init_vet360_id
        transaction = AsyncTransaction::Vet360::InitializePersonTransaction.start(@current_user, response)

        render json: transaction, serializer: AsyncTransaction::BaseSerializer
      end

      private

      def invalidate_mvi_cache
        @current_user.mvi&.destroy
      end
    end
  end
end
