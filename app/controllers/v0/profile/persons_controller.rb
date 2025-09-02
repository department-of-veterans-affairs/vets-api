# frozen_string_literal: true

require 'va_profile/person/service'
require 'va_profile/person/v2/service'

module V0
  module Profile
    class PersonsController < ApplicationController
      include Vet360::Transactionable
      service_tag 'profile'

      after_action :invalidate_mpi_cache

      def initialize_vet360_id
        response = if Flipper.enabled?(:remove_pciu, @current_user)
                     VAProfile::Person::V2::Service.new(@current_user).init_vet360_id
                   else
                     VAProfile::Person::Service.new(@current_user).init_vet360_id
                   end
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
