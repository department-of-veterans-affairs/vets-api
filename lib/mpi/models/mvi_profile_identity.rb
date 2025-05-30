# frozen_string_literal: true

require_relative 'mvi_profile_address'

module MPI
  module Models
    module MviProfileIdentity
      extend ActiveSupport::Concern

      included do
        include ActiveModel::Attributes
        attribute :given_names, array: true, default: []
        attribute :family_name, :string
        attribute :preferred_names, array: true, default: []
        attribute :suffix, :string
        attribute :gender, :string
        attribute :birth_date, :string
        attribute :deceased_date, :string
        attribute :ssn, :string
        attribute :address, :mvi_profile_address
        attribute :home_phone, :string
        attribute :person_types, array: true, default: []

        def birth_date=(value)
          return unless value

          birth_date = value.is_a?(String) ? Time.parse(value).iso8601 : birth_date
          super(birth_date)
        rescue ArgumentError
          nil
        end

        def deceased_date=(value)
          return unless value

          deceased_date = value.is_a?(String) ? Time.parse(value).iso8601 : deceased_date
          super(deceased_date)
        rescue ArgumentError
          nil
        end

        def address=(value)
          return unless value

          super(value.is_a?(MviProfileAddress) ? value : MviProfileAddress.new(value))
        end

        def normalized_suffix
          case suffix
          when /jr\.?/i
            'Jr.'
          when /sr\.?/i
            'Sr.'
          when /iii/i
            'III'
          when /ii/i
            'II'
          when /iv/i
            'IV'
          end
        end
      end
    end
  end
end
