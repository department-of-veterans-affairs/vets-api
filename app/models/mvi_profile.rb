# frozen_string_literal: true
class MviProfileAddress
  include Virtus.model

  attribute :street, String
  attribute :city, String
  attribute :state, String
  attribute :postal_code, String
  attribute :country, String
end

class MviProfile
  include Virtus.model

  attribute :given_names, Array[String]
  attribute :family_name, String
  attribute :suffix, String
  attribute :gender, String
  attribute :birth_date, String
  attribute :ssn, String
  attribute :address, MviProfileAddress
  attribute :home_phone, String
  attribute :icn, String
  attribute :mhv_ids, Array[String]
  attribute :edipi, String
  attribute :participant_id, String

  def mhv_correlation_id
    @mhv_ids&.first
  end
end
