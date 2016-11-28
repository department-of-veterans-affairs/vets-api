# frozen_string_literal: true
module EVSS
  class SnakeCaseMiddleware < FaradayMiddleware::ParseJson
    define_parser do |body|
      return if body.strip.empty?
      json = ::JSON.parse body
      json.deep_transform_keys!(&:underscore)
      json
    end
  end
end
