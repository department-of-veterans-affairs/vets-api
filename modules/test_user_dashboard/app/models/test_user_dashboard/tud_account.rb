# frozen_string_literal: true

module TestUserDashboard
  class TudAccount < ApplicationRecord
    self.ignored_columns = %w[standard available]

    ID_PROVIDERS = %w[idme dslogon mhv logingov].freeze

    validates :first_name, :last_name, :email, :id_type, presence: true
    validates :email, uniqueness: true
    validates :id_type, inclusion: { in: ID_PROVIDERS }

    serialize :services

    def available?
      checkout_time.nil?
    end

    def user_values(user)
      {
        first_name: user.first_name,
        middle_name: user.middle_name,
        last_name: user.last_name,
        gender: user.gender,
        birth_date: user.birth_date,
        ssn: user.ssn,
        phone: user.pciu_primary_phone,
        loa: user.loa,
        idme_uuid: user.idme_uuid,
        services: Users::Services.new(user).authorizations
      }
    end

    def user_identity
      unless (identity = UserIdentity.find(account_uuid))
        identity = UserIdentity.create(
          uuid: account_uuid,
          email: email,
          first_name: first_name,
          last_name: last_name,
          gender: gender,
          birth_date: birth_date.to_s(:iso_8601),
          ssn: ssn,
          loa: { lowest: 1, highest: 3 }
        )
      end
      identity
    end

    def mpi_profile
      MPI::Service.new.find_profile(user_identity).profile
    end

    def profile
      Users::Profile.new(user).pre_serialize
    end

    def user
      # ensure we have a user identity before instantiating
      user_identity
      User.new(uuid: user_identity.uuid)
    end
  end
end
