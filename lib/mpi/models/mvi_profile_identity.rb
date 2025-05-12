# frozen_string_literal: true

require 'mpi/type/profile_address'

module MPI
  module Models
    module MviProfileIdentity
      extend ActiveSupport::Concern

      included do
        include ActiveModel::Attributes

        attribute :given_names,     array: true, default: []
        attribute :family_name,     :string
        attribute :preferred_names, array: true, default: []
        attribute :suffix,          :string
        attribute :gender,          :string
        attribute :birth_date,      :date
        attribute :deceased_date,   :date
        attribute :ssn,             :string
        attribute :address,         :mpi_profile_address
        attribute :home_phone,      :string
        attribute :person_types,    array: true, default: []
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
