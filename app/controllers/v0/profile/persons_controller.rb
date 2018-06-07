# frozen_string_literal: true

module V0
  module Profile
    class PersonsController < ApplicationController
      include Vet360::Writeable

      after_action :invalidate_cache

      def initialize_vet360_id
        response    = Vet360::Person::Service.new(@current_user).init_vet360_id
        transaction = AsyncTransaction::Vet360::InitializePersonTransaction.start(@current_user, response)

        render json: transaction, serializer: AsyncTransaction::BaseSerializer
      end
    end
  end
end
