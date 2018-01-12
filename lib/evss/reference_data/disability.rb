# frozen_string_literal: true
require 'common/models/base'

module EVSS
  module ReferenceData
    class Disability < Common::Base
      attribute :name, String
      attribute :end_date, Integer
    end
  end
end
