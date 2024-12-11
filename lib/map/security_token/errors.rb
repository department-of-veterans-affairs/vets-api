# frozen_string_literal: true

module MAP
  module SecurityToken
    module Errors
      class ApplicationMismatchError < StandardError; end
      class MissingICNError < StandardError; end
    end
  end
end
