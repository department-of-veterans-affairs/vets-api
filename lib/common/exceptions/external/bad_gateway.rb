# frozen_string_literal: true

require 'common/exceptions/external/service_error'

module Common
  module Exceptions::External
    class BadGateway < ServiceError
    end
  end
end
