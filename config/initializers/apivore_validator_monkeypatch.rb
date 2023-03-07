# frozen_string_literal: true

module Apivore
  class Validator
    def matches?(swagger_checker)
      pre_checks(swagger_checker)

      unless has_errors?
        args = RailsShim.action_dispatch_request_args(
          full_path(swagger_checker),
          params: params['_data'] || {},
          headers: params['_headers'] || {}
        )
        send(method, args[0], **args[1])
        swagger_checker.response = response
        post_checks(swagger_checker)

        if has_errors? && response.body.length.positive?
          errors << "\nResponse body:\n #{JSON.pretty_generate(JSON.parse(response.body))}"
        end

        swagger_checker.remove_tested_end_point_response(
          path, method, expected_response_code
        )
      end

      !has_errors?
    end
  end
end
