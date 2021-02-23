# frozen_string_literal: true

module TestUserDashboard
  class TudAccount < ApplicationRecord
    self.ignored_columns = ['standard']

    ID_PROVIDERS = %w[id_me dslogon mhv].freeze

    validates :first_name, :last_name, :email, :gender, presence: true
    validates :email, uniqueness: true

    # uncomment when adding id_provider column information
    # validates :id_provider, presence: true
    # validates :id_provider, inclusion: { in: ID_PROVIDERS }
    def available?
      checkout_time.nil?
    end

    def services
      profile.services
    end

    private

    def uuid
      1234
    end

    def user_identity
      unless identity = UserIdentity.find(uuid)
        identity = UserIdentity.create(uuid:       1234,
                                       email:      email,
                                       first_name: first_name,
                                       last_name:  last_name,
                                       gender:     gender,
                                       birth_date: birth_date.to_s(:iso_8601),
                                       ssn:        ssn,
                                       loa:        {lowest: 1, highest: 3})
      end
      identity
    end

    def user
      User.new(uuid: uuid)
    end

    def profile
      Users::Profile.new(user).pre_serialize
    end

    def mpi_profile
      MPI::Service.new.find_profile(user_identity).profile
    end
  end
end
