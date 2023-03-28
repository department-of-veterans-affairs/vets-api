# frozen_string_literal: true

require 'jwt'
require 'net/http'
require 'openssl'
require 'uri'

def prompt(prompt, *setting_path)
  unless setting_path.empty?
    configured_value = Settings.dig(*setting_path)
    return configured_value if configured_value.present?
  end

  p = prompt
  p += " (configure at Settings.#{setting_path.join('.')})" unless setting_path.empty?
  p += ': '

  $stdout.puts p
  $stdin.gets.strip
end

def openid_metadata
  @openid_metadata ||= JSON.parse(
    Net::HTTP.get(URI(prompt('OpenID well-known config URI', :modules_appeals_api, :token_generation, :config_uri)))
  ).with_indifferent_access
end

def api_host
  URI(openid_metadata[:token_endpoint]).host
end

def post_form_data(url, data, headers: {})
  uri = URI(url)
  request = Net::HTTP::Post.new(uri.request_uri, headers)
  request.set_form_data(data)
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.request(request)
end

def base64_url_encode(str)
  Base64.urlsafe_encode64(str, padding: false).gsub('=', '')
end

# See https://developer.va.gov/explore/authorization/docs/client-credentials
# rubocop:disable Metrics/MethodLength
def generate_ccg_token(api_name = nil)
  client_id = prompt(
    'Client ID',
    :modules_appeals_api, :token_generation, :ccg, :client_id
  )
  private_key_path = prompt(
    'Path to private key',
    :modules_appeals_api, :token_generation, :ccg, :private_key_path
  )
  scopes = api_scopes(api_name)

  token_uri = openid_metadata[:token_endpoint]
  puts "Fetching CCG token (#{scopes.join(', ')}) from '#{token_uri}'..."

  # Audience must match the okta endpoint used to request the token
  ccg_audience = "#{openid_metadata[:issuer]}/v1/token"
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

def configured_api_key(api_name)
  return nil if api_name.blank?

  Settings.dig(:modules_appeals_api, :token_validation, api_name.to_sym, :api_key)
end

# See https://sandbox-api.va.gov/internal/auth/docs/v2/validation.json
# rubocop:disable Metrics/MethodLength
def validate_token(api_name = nil)
  puts 'Validating token...'

  api_key = configured_api_key(api_name)

  if api_key.blank?
    API_NAMES.each do |name|
      api_key = configured_api_key(name)
      break if api_key.present?
    end
  end

  api_key = prompt('Token validation service API key') if api_key.blank?
  token = prompt('Token to validate')

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
# rubocop:enable Metrics/MethodLength

API_NAMES = %w[appeals_status contestable_issues higher_level_reviews legacy_appeals
               notice_of_disagreements supplemental_claims].freeze

def api_scopes(api_name = nil)
  return %w[appeals.read appeals.write] if api_name.blank?

  {
    appeals_status: AppealsApi::V1::AppealsController::OAUTH_SCOPES,
    contestable_issues: AppealsApi::ContestableIssues::V0::ContestableIssuesController::OAUTH_SCOPES,
    higher_level_reviews: AppealsApi::HigherLevelReviews::V0::HigherLevelReviewsController::OAUTH_SCOPES,
    legacy_appeals: AppealsApi::LegacyAppeals::V0::LegacyAppealsController::OAUTH_SCOPES,
    notice_of_disagreements: AppealsApi::NoticeOfDisagreements::V0::NoticeOfDisagreementsController::OAUTH_SCOPES,
    supplemental_claims: AppealsApi::SupplementalClaims::V0::SupplementalClaimsController::OAUTH_SCOPES
  }[api_name.to_sym].values.flatten.uniq
end

def abbreviate_snake_case_name(name)
  name.scan(/(?<=^|_)(\S)/).join
end

namespace :appeals_api do
  namespace :token do
    desc 'Get a CCG token for all appeals APIs'
    task ccg: :environment do
      generate_ccg_token
    end

    desc 'Validate an OpenID (CCG or Okta) token'
    task validate: :environment do
      validate_token
    end

    API_NAMES.each do |api_name|
      namespace abbreviate_snake_case_name(api_name).to_sym do
        desc "Get a CCG token for #{api_name}"
        task ccg: :environment do
          generate_ccg_token(api_name)
        end

        desc "Validate an OpenID (CCG or Okta) token for #{api_name}"
        task validate: :environment do
          validate_token(api_name)
        end
      end
    end
  end
end
