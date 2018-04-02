# frozen_string_literal: true

module RequestHelper
  def options(*args)
    reset! unless integration_session
    integration_session.__send__(:process, :options, *args).tap do
      copy_session_variables!
    end
  end

  # Returns an array of errors from the passed JSON
  #
  # @param response [String] A response as a string of JSON
  # @return [Array] An array of error messages from the passed response
  #
  def errors_for(response)
    parsed_body = JSON.parse response.body

    parsed_body['errors'].map { |error| error['detail'] }
  end
end
