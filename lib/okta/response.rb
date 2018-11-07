# frozen_string_literal: true

module Okta
  class Response
    attr_accessor :status, :body

    def initialize(resp)
      @status = resp.status
      @body = resp.body
    end

    def success?
      status == 200 || status == 204
    end

    alias cache? success?
  end
end
