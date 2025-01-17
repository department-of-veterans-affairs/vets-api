# frozen_string_literal: true

module TestUserDashboard
  class TudAccount < ApplicationRecord
    self.ignored_columns += %w[standard available account_type id_type]

    ID_PROVIDERS = %w[idme dslogon mhv logingov].freeze

    validates :first_name, :last_name, :email, :id_types, presence: true
    validates :email, uniqueness: true
    validate :valid_id_types

    serialize :services, coder: YAML

    def available?
      checkout_time.nil?
    end

    def user_identity
      unless (identity = UserIdentity.find(account_uuid))
        identity = UserIdentity.create(
          uuid: account_uuid,
          email:,
          first_name:,
          last_name:,
          gender:,
          birth_date: birth_date.to_s(:iso_8601),
          ssn:,
          loa: { lowest: 1, highest: 3 }
        )
      end
      identity
    end

    def mpi_profile
      MPI::Service.new.find_profile_by_attributes(first_name: user_identity.first_name,
                                                  last_name: user_identity.last_name,
                                                  ssn: user_identity.ssn,
                                                  birth_date: user_identity.birth_date).profile
    end

    def profile
      Users::Profile.new(user).pre_serialize
    end

    def user
      # ensure we have a user identity before instantiating
      user_identity
      User.new(uuid: user_identity.uuid)
    end

    private

    def valid_id_types
      errors.add(:id_types, 'id_type is invalid') if id_types.detect { |type| ID_PROVIDERS.exclude?(type) }
    end
  end
end
