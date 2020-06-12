# frozen_string_literal: true

require 'common/exceptions/external/service_error'

module Common
  module Exceptions::External
    class UnprocessableEntity < ServiceError
    end
  end
end
