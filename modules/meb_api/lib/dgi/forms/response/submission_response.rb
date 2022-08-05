# frozen_string_literal: true

require 'dgi/response'

module MebApi
  module DGI
    module Forms
      module Submission
        class Response < MebApi::DGI::Response
          def initialize(status, _response = nil)
            super(status, attributes)
          end
        end
      end
    end
  end
end
