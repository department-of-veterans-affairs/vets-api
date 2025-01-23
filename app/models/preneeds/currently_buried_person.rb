# frozen_string_literal: true

module Preneeds
  # Models a currently buried person under a veteran's benefit from a {Preneeds::BurialForm} form
  #
  # @!attribute cemetery_number
  #   @return [String] cemetery number
  # @!attribute name
  #   @return [Preneeds::FullName] currently buried person's full name
  #
  class CurrentlyBuriedPerson < Preneeds::Base
    attribute :cemetery_number, String
    attribute :name, Preneeds::FullName

    # (see Preneeds::BurialForm#as_eoas)
    #
    def as_eoas
      { cemeteryNumber: cemetery_number, name: name.as_eoas }
    end

    # (see Preneeds::Applicant.permitted_params)
    #
    def self.permitted_params
      [:cemetery_number, { name: Preneeds::FullName.permitted_params }]
    end
  end
end
