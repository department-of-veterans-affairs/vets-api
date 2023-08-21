# frozen_string_literal: true

module RequestHelper
  def options(*)
    reset! unless integration_session
    integration_session.__send__(:process, :options, *).tap do
      copy_session_variables!
    end
  end

  # Returns an array of errors from the passed JSON
  #
  # @param response [String] A response as a string of JSON
  # @return [Array] An array of error messages from the passed response
  #
  def errors_for(response)
    parsed_body = JSON.parse(response.body)

    parsed_body['errors'].map { |error| error['detail'] }
  end

  # Returns a JSON object with the contents of the response body 'data' attribute
  #
  # @param response [String] A response as a string of JSON
  # @return [Hash] A hash of the response body data
  #
  def json_body_for(response)
    JSON.parse(response.body)['data']
  end
end
