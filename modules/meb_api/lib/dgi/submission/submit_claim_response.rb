# frozen_string_literal: true

require 'dgi/response'

module MebApi
  module DGI
    module Submission
      class SubmissionResponse < MebApi::DGI::Response
        def initialize(status, _response = nil)
          super(status, attributes)
        end
      end
    end
  end
end
