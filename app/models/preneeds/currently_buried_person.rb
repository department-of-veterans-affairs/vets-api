# frozen_string_literal: true
require 'common/models/base'

module Preneeds
  class CurrentlyBuriedPerson < Preneeds::Base
    attribute :cemetery_number, String
    attribute :name, Preneeds::FullName

    def as_eoas
      { cemeteryNumber: cemetery_number, name: name.as_eoas }.compact
    end

    def self.permitted_params
      [:cemetery_number, name: Preneeds::FullName.permitted_params]
    end
  end
end
