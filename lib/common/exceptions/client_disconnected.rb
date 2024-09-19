# frozen_string_literal: true

require 'common/exceptions/service_error'

module Common
  module Exceptions
    class ClientDisconnected < ServiceError
    end
  end
end
