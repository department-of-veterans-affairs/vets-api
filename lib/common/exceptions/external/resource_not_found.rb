# frozen_string_literal: true

require 'common/exceptions/external/service_error'

module Common
  module Exceptions::External
    class ResourceNotFound < ServiceError
    end
  end
end
