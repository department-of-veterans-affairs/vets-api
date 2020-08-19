# frozen_string_literal: true

module Okta
  class Response
    attr_accessor :headers, :status, :body

    def initialize(resp)
      @headers = resp.headers
      @status = resp.status
      @body = resp.body
    end

    def success?
      status == 200 || status == 204
    end

    alias cache? success?
  end
end
