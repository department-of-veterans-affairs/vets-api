# frozen_string_literal: true

require 'sign_in/idme/configuration'

module SignIn::Idme
  class Service < Common::Client::Base
    configuration SignIn::Idme::Configuration

    attr_accessor :scope

    def render_auth(state: SecureRandom.hex)
      renderer = ActionController::Base.renderer
      renderer.controller.prepend_view_path(Rails.root.join('lib', 'sign_in', 'templates'))
      renderer.render(template: 'oauth_get_form',
                      locals: {
                        url: auth_url,
                        params:
                        {
                          scope: scope || LOA::IDME_LOA3,
                          state: state,
                          client_id: config.client_id,
                          redirect_uri: config.redirect_uri,
                          response_type: config.response_type
                        }
                      },
                      format: :html)
    end

    def normalized_attributes(user_info)
      {
        uuid: user_info.sub,
        idme_uuid: user_info.sub,
        loa: { current: user_info.level_of_assurance, highest: user_info.level_of_assurance },
        ssn: user_info.social&.tr('-', ''),
        birth_date: user_info.birth_date,
        first_name: user_info.fname,
        last_name: user_info.lname,
        email: user_info.email,
        sign_in: { service_name: config.service_name }
      }
    end

    def token(code)
      response = perform(
        :post, config.token_path, token_params(code), { 'Content-Type' => 'application/json' }
      )
      response.body
    rescue Common::Client::Errors::ClientError => e
      raise e
    end

    def user_info(token)
      response = perform(:get, config.userinfo_path, nil, { 'Authorization' => "Bearer #{token}" })
      jwt_decode(response.body)
    rescue Common::Client::Errors::ClientError => e
      raise e
    end

    private

    def jwt_decode(encoded_jwt)
      decoded_jwt = JWT.decode(encoded_jwt, false, nil)&.first
      OpenStruct.new(decoded_jwt)
    end

    def auth_url
      "#{config.base_path}/#{config.auth_path}"
    end

    def token_params(code)
      {
        grant_type: config.grant_type,
        code: code,
        client_id: config.client_id,
        client_secret: config.client_secret,
        redirect_uri: config.redirect_uri
      }.to_json
    end
  end
end
