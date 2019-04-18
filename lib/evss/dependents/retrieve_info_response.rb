# frozen_string_literal: true

module EVSS
  module Dependents
    class RetrieveInfoResponse < EVSS::Response
      attribute :body, Hash
    end
  end
end
