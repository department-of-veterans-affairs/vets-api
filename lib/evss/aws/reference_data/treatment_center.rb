# frozen_string_literal: true
require 'common/models/base'

module EVSS
  module AWS
    module ReferenceData
      class TreatmentCenter < Common::Base
        attribute :city, String
        attribute :id, Integer
        attribute :name, Integer
        attribute :state, Integer
      end
    end
  end
end
