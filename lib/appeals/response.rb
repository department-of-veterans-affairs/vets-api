# frozen_string_literal: true

module Appeals
  class Response < Common::Client::Response
    attribute :appeals_series, Array[Models::Appeal]
  end
end
