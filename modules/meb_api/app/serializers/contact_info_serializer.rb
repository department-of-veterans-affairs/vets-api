# frozen_string_literal: true

class ContactInfoSerializer
  include JSONAPI::Serializer

  set_id { '' }
  attributes :phone, :email
end
