# frozen_string_literal: true

require 'disability_compensation/providers/rated_disabilities/rated_disabilities_provider'
require 'disability_compensation/responses/rated_disabilities_response'

class EvssRatedDisabilitiesProvider
  include RatedDisabilitiesProvider
  def initialize(current_user)
    @service = EVSS::DisabilityCompensationForm::Service.new(auth_headers(current_user))
  end

  # @param [string] _client_id: (unused) the lighthouse_client_id requested from Lighthouse
  # @param [string] _rsa_key_path: (unused) path to the private RSA key used to create the lighthouse_client_id
  def get_rated_disabilities(_client_id = nil, _rsa_key_path = nil)
    data = @service.get_rated_disabilities
    transform(data)
  end

  def auth_headers(current_user)
    EVSS::DisabilityCompensationAuthHeaders.new(current_user).add_headers(EVSS::AuthHeaders.new(current_user).to_h)
  end

  def transform(data)
    rated_disabilities =
      data[:rated_disabilities].map do |rated_disability|
        DisabilityCompensation::ApiProvider::RatedDisability.new(
          name: rated_disability['name'],
          decision_code: rated_disability['decision_code'],
          decision_text: rated_disability['decision_text'],
          diagnostic_code: rated_disability['diagnostic_code'],
          effective_date: rated_disability['effective_date'],
          rated_disability_id: rated_disability['rated_disability_id'],
          rating_decision_id: rated_disability['rating_decision_id'],
          rating_percentage: rated_disability['rating_percentage'],
          related_disability_date: rated_disability['related_disability_date'],
          special_issues: rated_disability['special_issues'].map do |special_issue|
            DisabilityCompensation::ApiProvider::SpecialIssue.new(
              code: special_issue['code'], name: special_issue['name']
            )
          end
        )
      end

    DisabilityCompensation::ApiProvider::RatedDisabilitiesResponse.new(rated_disabilities:)
  end
end
