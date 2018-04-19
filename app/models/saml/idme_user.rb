

require 'active_model'

module Saml
  class IdmeUser
    extend ActiveModel::Naming
    include ActiveModel::Serialization

    attr_accessor :fname,
                  :lname,
                  :mname,
                  :social,
                  :gender,
                  :birth_date,
                  # ID.me required attributes
                  :uuid,
                  :email,
                  :multifactor,
                  :level_of_assurance
  end
end
