# frozen_string_literal: true

require 'common/exceptions/resource_not_found'

module Vye
  class ResourceNotFound < Common::Exceptions::ResourceNotFound
    # Inherits all functionality from Common::Exceptions::ResourceNotFound
    # This provides a 404 status code and appropriate error format
  end
end
