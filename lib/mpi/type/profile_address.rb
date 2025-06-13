# frozen_string_literal: true

require 'mpi/models/mvi_profile_address'

module MPI
  module Type
    class ProfileAddress < ActiveModel::Type::Value
      def cast(value)
        case value
        when Models::MviProfileAddress
          value
        when Hash
          Models::MviProfileAddress.new(value)
        end
      end
    end
  end
end

ActiveModel::Type.register(:mpi_profile_address, MPI::Type::ProfileAddress)
