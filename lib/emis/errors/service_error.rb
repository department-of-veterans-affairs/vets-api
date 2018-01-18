# frozen_string_literal: true

module EMIS
  module Errors
    # Indicates an error recieved from the eMIS service itself
    class ServiceError < StandardError
    end
  end
end
