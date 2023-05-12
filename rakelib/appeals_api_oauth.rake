# frozen_string_literal: true

require 'jwt'
require 'net/http'
require 'openssl'
require 'uri'

# rubocop:disable Metrics/ModuleLength
module AppealsRakeHelpers
  API_NAMES = %w[appeals_status contestable_issues higher_level_reviews legacy_appeals
                 notice_of_disagreements supplemental_claims].freeze

  class << self
    # Load a value from a settings.yml or prompt the user if it's not there
    def prompt(prompt_text, *setting_path)
      if setting_path.present?
        configured_value = Settings.dig(*setting_path)
        return configured_value if configured_value.present?
      end

      p = prompt_text
      p += " (configure at Settings.#{setting_path.join('.')})" if setting_path.present?
      p += ': '

      $stdout.puts p
      $stdin.gets.strip
    end

    def configured_api_key(api_name)
      if api_name.blank?
        # Validation API keys are able to validate any token, regardless of which scopes it has, so use the first
        # available key if no API specified:
        API_NAMES.each do |name|
          api_key = configured_api_key(name)
          return api_key if api_key.present?
        end
      end

      Settings.dig(:modules_appeals_api, :token_validation, api_name.to_sym, :api_key)
    end

    def fetch_openid_metadata(ccg: false)
      config_uri = prompt('OpenID well-known config URI',
                          :modules_appeals_api, :token_generation, ccg ? :ccg : :auth_code_flow, :config_uri)

      JSON.parse(Net::HTTP.get(URI(config_uri))).with_indifferent_access
    end

    def post_form_data(url, data, headers: {})
      uri = URI(url)
      request = Net::HTTP::Post.new(uri.request_uri, headers)
      request.set_form_data(data)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.request(request)
    end

    def generate_auth_code_flow_token(api_name = nil)
      user_email = prompt('OAuth user email', :modules_appeals_api, :token_generation, :auth_code_flow, :user_email)
      user_password = prompt('OAuth user password',
                             :modules_appeals_api, :token_generation, :auth_code_flow, :user_password)
      client_id = prompt('Client ID', :modules_appeals_api, :token_generation, :auth_code_flow, :client_id)
      client_secret = prompt('Client Secret', :modules_appeals_api, :token_generation, :auth_code_flow, :client_secret)
      redirect_uri = prompt('Redirect URI', :modules_appeals_api, :token_generation, :auth_code_flow, :redirect_uri)
      scopes = api_scopes(api_name, ccg: false).join(' ')

      cmd = <<~CMD
        docker run --rm vasdvp/lighthouse-auth-utils:latest auth \\
                   --user-email=#{user_email} \\
                   --user-password='#{user_password}' \\
                   --client-id=#{client_id} \\
                   --client-secret=#{client_secret} \\
                   --redirect-uri=#{redirect_uri} \\
                   --scope="#{scopes}" \\
                   --authorization-url=https://sandbox-api.va.gov/oauth2/appeals/v1
      CMD
      exec cmd
    end

    # See https://developer.va.gov/explore/authorization/docs/client-credentials
    # N.B. lighthouse-auth-utils container is able to generate tokens for auth code flow and CCG, but it can't generate
    # CCG tokens RSA keys (this is not supported by its underlying libraries), so it is not used here.
    # rubocop:disable Metrics/MethodLength
    def generate_ccg_token(api_name = nil)
      client_id = prompt('Client ID', :modules_appeals_api, :token_generation, :ccg, :client_id)
      private_key_path = prompt('Path to private key', :modules_appeals_api, :token_generation, :ccg, :private_key_path)

      scopes = api_scopes(api_name)
      metadata = fetch_openid_metadata(ccg: true)
      token_uri = metadata[:token_endpoint]

      puts "Fetching CCG token with scopes #{scopes.join(', ')} from '#{token_uri}'"

      # Audience must match the okta endpoint used to request the token
      ccg_audience = "#{metadata[:issuer]}/v1/token"
      header_content = { 'typ' => 'JWT', 'alg' => 'RS256' }
      iat = Time.now.to_i
      payload_content = {
        'aud' => ccg_audience,
        'iss' => client_id,
        'sub' => client_id,
        'iat' => iat,
        'exp' => iat + 300 #  The maximum allowed lifetime is 300 seconds (5 minutes)
      }
      private_key = OpenSSL::PKey.read(File.read(private_key_path))
      client_assertion = JWT.encode(payload_content, private_key, 'RS256', header_content)
      client_assertion_type = 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer'

      result = post_form_data(
        token_uri,
        {
          'grant_type' => 'client_credentials',
          'client_assertion' => client_assertion,
          'client_assertion_type' => client_assertion_type,
          'scope' => scopes.join(' ')
        }
      )

      raise "Unsuccessful token request to #{token_uri}:\n#{result.inspect} #{result.body}" if result.code.to_i >= 400

      puts JSON.pretty_generate(JSON.parse(result.body))
    end
    # rubocop:enable Metrics/MethodLength

    # See https://sandbox-api.va.gov/internal/auth/docs/v2/validation.json
    def validate_token(api_name = nil, ccg: false)
      token = prompt('Token to validate')
      api_key = configured_api_key(api_name) || prompt('Token validation service API key')

      metadata = fetch_openid_metadata(ccg:)
      api_host = URI(metadata[:token_endpoint]).host
      validation_uri = "https://#{api_host}/internal/auth/v3/validation"

      # sandbox is correct here for non-prod tokens (including with dev-api.va.gov, for example)
      validation_host = api_host == 'api.va.gov' ? 'api.va.gov' : 'sandbox-api.va.gov'
      validation_audience = "https://#{validation_host}/services/appeals"

      result = post_form_data(
        validation_uri,
        { 'aud' => validation_audience },
        headers: { 'Authorization' => "Bearer #{token}", 'apikey' => api_key }
      )

      if result.code.to_i >= 400
        raise "Unsuccessful validation request to #{validation_uri}:\n#{result.inspect} #{result.body}"
      end

      puts JSON.pretty_generate(JSON.parse(result.body))
    end

    def api_scopes(api_name = nil, ccg: true)
      # Valid scopes for CCG are those starting with `system/`
      find_ccg_scopes = ->(scope_list) { scope_list.flatten.uniq.filter { |s| s.start_with? 'system/' } }
      # Other scopes (`veteran/*` and `representative/*`) are used with auth code flow
      find_non_ccg_scopes = ->(scope_list) { scope_list.flatten.uniq.reject { |s| s.start_with? 'system/' } }

      find_scopes = ccg ? find_ccg_scopes : find_non_ccg_scopes

      if api_name.blank?
        find_scopes.call(AppealsApi::OpenidAuth::DEFAULT_OAUTH_SCOPES.values)
      else
        find_scopes.call(
          {
            appeals_status: AppealsApi::V1::AppealsController::OAUTH_SCOPES,
            appealable_issues: AppealsApi::AppealableIssues::V0::AppealableIssuesController::OAUTH_SCOPES,
            higher_level_reviews: AppealsApi::HigherLevelReviews::V0::HigherLevelReviewsController::OAUTH_SCOPES,
            legacy_appeals: AppealsApi::LegacyAppeals::V0::LegacyAppealsController::OAUTH_SCOPES,
            notice_of_disagreements:
              AppealsApi::NoticeOfDisagreements::V0::NoticeOfDisagreementsController::OAUTH_SCOPES,
            supplemental_claims: AppealsApi::SupplementalClaims::V0::SupplementalClaimsController::OAUTH_SCOPES
          }[api_name.to_sym].values
        )
      end
    end

    def abbreviate_snake_case_name(name) = name.scan(/(?<=^|_)(\S)/).join
  end
end
# rubocop:enable Metrics/ModuleLength

namespace :appeals_api do
  namespace :token do
    desc 'Get a CCG token for all appeals APIs'
    task ccg: :environment do
      AppealsRakeHelpers.generate_ccg_token
    end

    desc 'Get an auth code flow token for all appeals APIs'
    task auth: :environment do
      AppealsRakeHelpers.generate_auth_code_flow_token
    end

    desc 'Validate an OpenID (CCG or auth code flow) token'
    task validate: :environment do
      AppealsRakeHelpers.validate_token
    end

    AppealsRakeHelpers::API_NAMES.each do |api_name|
      namespace AppealsRakeHelpers.abbreviate_snake_case_name(api_name).to_sym do
        desc "Get a CCG token for #{api_name}"
        task ccg: :environment do
          AppealsRakeHelpers.generate_ccg_token(api_name)
        end

        desc "Get an auth code flow token for all #{api_name}"
        task auth: :environment do
          AppealsRakeHelpers.generate_auth_code_flow_token(api_name)
        end

        desc "Validate an OpenID (CCG or auth code flow) token for #{api_name}"
        task validate: :environment do
          AppealsRakeHelpers.validate_token(api_name)
        end
      end
    end
  end
end
