# frozen_string_literal: true

class AutomationSerializer < ActiveModel::Serializer
  attribute :claimant_id
  attribute :suffix
  attribute :date_of_birth
  attribute :first_name
  attribute :last_name
  attribute :middle_name
  attribute :notification_method
  attribute :preferred_contact
  attribute :address_line_1
  attribute :address_line_2
  attribute :city
  attribute :zipcode
  attribute :email_address
  attribute :address_type
  attribute :mobile_phone_number
  attribute :home_phone_number
  attribute :country_code
  attribute :state_code

  def id
    nil
  end
end
