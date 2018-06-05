# frozen_string_literal: true

require 'vet360/response'

module Vet360
  module ReferenceData
    class ReferenceDataResponse < Vet360::Response
      attribute :data, Hash
    end
  end
end
