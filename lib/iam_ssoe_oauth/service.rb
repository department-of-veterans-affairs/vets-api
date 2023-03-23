# frozen_string_literal: true

require 'uri'
require 'iam_ssoe_oauth/configuration'

module IAMSSOeOAuth
  # Class used to connect to IAM's SSOe Oauth service which validates tokens
  # and given a valid token returns a set of user traits.
  # https:://dvagov.sharepoint.com/sites/OITEPMOIA/playbooks/Pages/OAuth/OAuth.aspx
  #
  # @example create a new instance and call the introspect endpoint
  #   token = 'ypXeAwQedpmAy5xFD2u5'
  #   service = IAMSSOeOAuth::Service.new
  #   response = service.post_introspect(token)
  #
  class Service < Common::Client::Base
    configuration IAMSSOeOAuth::Configuration

    CLIENT_ID = Settings.iam_ssoe.client_id
    TOKEN_TYPE_HINT = 'access_token'
    INTROSPECT_PATH = '/oauthe/sps/oauth/oauth20/introspect'

    # Validate a user's auth token and returns either valid active response with a set
    # of user traits or raise's an unauthorized error if the response comes back as invalid.
    # https:://dvagov.sharepoint.com/sites/OITEPMOIA/playbooks/Pages/OAuth/OAuth Example - Introspect.aspx
    #
    # @token String the auth token for the user
    #
    # @return Hash active user traits
    #
    def post_introspect(token)
      response = perform(
        :post, INTROSPECT_PATH, encoded_params(token), { 'Content-Type' => 'application/x-www-form-urlencoded' }
      )
      raise Common::Exceptions::Unauthorized, detail: 'IAM user session is inactive' if inactive?(response)

      response.body
    rescue Common::Client::Errors::ClientError => e
      remap_error(e)
    end

    private

    def encoded_params(token)
      URI.encode_www_form(
        {
          client_id: CLIENT_ID,
          token:,
          token_type_hint: TOKEN_TYPE_HINT
        }
      )
    end

    def inactive?(response)
      !response.body[:active]
    end

    def remap_error(e)
      case e.status
      when 400
        raise Common::Exceptions::BackendServiceException.new('IAM_SSOE_400', detail: e.body)
      when 500
        raise Common::Exceptions::BackendServiceException, 'IAM_SSOE_502'
      else
        raise e
      end
    end
  end
end
