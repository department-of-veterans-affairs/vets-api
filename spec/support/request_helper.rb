# frozen_string_literal: true

module RequestHelper
  def options(*args)
    reset! unless integration_session
    integration_session.__send__(:process, :options, *args).tap do
      copy_session_variables!
    end
  end

  def errors_for(response)
    parsed_body = JSON.parse response.body

    parsed_body['errors'].map { |error| error['detail'] }
  end
end
