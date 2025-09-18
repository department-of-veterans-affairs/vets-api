# frozen_string_literal: true

require 'dgi/response'

module MebApi
  module DGI
    module Submission
      class SubmissionResponse < MebApi::DGI::Response
        def initialize(status, _response = nil)
          super(status, nil)
        end
      end
    end
  end
end
