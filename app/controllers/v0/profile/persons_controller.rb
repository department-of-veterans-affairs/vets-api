# frozen_string_literal: true

require 'va_profile/person/service'

module V0
  module Profile
    class PersonsController < ApplicationController
      include Vet360::Transactionable
      service_tag 'profile'

      after_action :invalidate_mpi_cache

      def initialize_vet360_id
        response = VAProfile::Person::Service.new(@current_user).init_vet360_id
        transaction = AsyncTransaction::VAProfile::InitializePersonTransaction.start(@current_user, response)

        render json: AsyncTransaction::BaseSerializer.new(transaction).serializable_hash
      end

      def status
        check_transaction_status!
      end

      private

      def invalidate_mpi_cache
        @current_user.invalidate_mpi_cache
      end
    end
  end
end
