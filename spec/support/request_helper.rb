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

  shared_context 'login_as_loa1' do
    let(:token) { 'abracadabra-open-sesame' }
    let(:auth_header) { ActionController::HttpAuthentication::Token.encode_credentials(token) }
    let(:loa1_user) { build(:user, :loa1) }
    def login_as_loa1
      Session.create(uuid: loa1_user.uuid, token: token)
      User.create(loa1_user)
      request.env['HTTP_AUTHORIZATION'] = auth_header
    end
  end
end
