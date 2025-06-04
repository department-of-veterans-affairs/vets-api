# frozen_string_literal: true

module HCA
  class UserAttributes
    include ActiveModel::Model
    include ActiveModel::Validations

    validates :first_name, presence: true
    validates :last_name, presence: true
    validates :birth_date, presence: true
    validates :ssn, presence: true

    attr_accessor :first_name,
                  :middle_name,
                  :last_name,
                  :birth_date,
                  :ssn,
                  :gender

    # These attributes, along with uuid, are required by mpi/service.
    # They can be nil as they're not part of the HCA form
    attr_reader :mhv_icn, :edipi, :authn_context, :idme_uuid, :logingov_uuid

    def initialize(attributes = {})
      super
      @ssn = attributes[:ssn]&.gsub(/\D/, '')
    end

    def to_h
      {
        first_name:,
        middle_name:,
        last_name:,
        birth_date:,
        ssn:
      }
    end

    delegate :uuid, to: :SecureRandom
  end
end
