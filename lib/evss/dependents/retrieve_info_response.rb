# frozen_string_literal: true

require 'evss/response'

module EVSS
  module Dependents
    class RetrieveInfoResponse < EVSS::Response
      attribute :body, Hash
    end
  end
end
