# frozen_string_literal: true

module TestUserDashboard
  class TudAccountSerializer
    include JSONAPI::Serializer

    attributes :account_uuid, :first_name, :middle_name, :last_name, :gender,
               :birth_date, :ssn, :phone, :email, :password, :checkout_time,
               :id_types, :loa, :services, :notes, :mfa_code

    attribute :available, &:available?
  end
end
