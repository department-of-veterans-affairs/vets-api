# frozen_string_literal: true

module Vye
  class AddressChangeSerializer < ActiveModel::Serializer
    attributes(
      :veteran_name,
      :address1,
      :address2,
      :address3,
      :address4,
      :address5,
      :city,
      :state,
      :zip_code,
      :origin
    )
  end
end
