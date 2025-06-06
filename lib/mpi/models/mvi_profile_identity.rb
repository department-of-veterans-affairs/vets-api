# frozen_string_literal: true

require 'mpi/type/datetime_string'
require 'mpi/type/profile_address'

module MPI
  module Models
    module MviProfileIdentity
      extend ActiveSupport::Concern

      included do
        attribute :address,         :mpi_profile_address
        attribute :birth_date,      :mpi_datetime_string
        attribute :deceased_date,   :mpi_datetime_string
        attribute :family_name,     :string
        attribute :gender,          :string
        attribute :given_names,     array: true, default: []
        attribute :home_phone,      :string
        attribute :person_types,    array: true, default: []
        attribute :preferred_names, array: true, default: []
        attribute :ssn,             :string
        attribute :suffix,          :string
      end

      def normalized_suffix
        case suffix
        when /jr\.?/i then 'Jr.'
        when /sr\.?/i then 'Sr.'
        when /iii/i   then 'III'
        when /ii/i    then 'II'
        when /iv/i    then 'IV'
        end
      end
    end
  end
end
