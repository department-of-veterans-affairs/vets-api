# frozen_string_literal: true

module TestUserDashboard
  class TudAccountSerializer < ActiveModel::Serializer
    attributes :id, :account_uuid, :first_name, :middle_name, :last_name, :gender,
               :birth_date, :ssn, :phone, :email, :password, :available, :checkout_time,
               :id_type, :loa, :account_type, :services, :notes

    def available
      object.available?
    end
  end
end
