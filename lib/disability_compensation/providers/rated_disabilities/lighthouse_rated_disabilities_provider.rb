# frozen_string_literal: true

require 'disability_compensation/providers/rated_disabilities/rated_disabilities_provider'
require 'lighthouse/veteran_verification/service'

class LighthouseRatedDisabilitiesProvider
  include RatedDisabilitiesProvider

  def initialize(icn)
    @service = VeteranVerification::Service.new
    @icn = icn
  end

  # @param [string] lighthouse_client_id: the lighthouse_client_id requested from Lighthouse
  # @param [string] lighthouse_rsa_key_path: path to the private RSA key used to create the lighthouse_client_id
  def get_rated_disabilities(lighthouse_client_id, lighthouse_rsa_key_path)
    auth_params = {
      launch: Base64.encode64(JSON.generate({ patient: @icn }))
    }
    data = @service.get_rated_disabilities(
      lighthouse_client_id,
      lighthouse_rsa_key_path,
      { auth_params: }
    )

    transform(data['data']['attributes']['individual_ratings'])
  end

  def transform(data)
    rated_disabilities =
      data.map do |rated_disability|
        DisabilityCompensation::ApiProvider::RatedDisability.new(
          name: rated_disability['diagnostic_type_name'],
          decision_code: decision_code_transform(rated_disability['decision']),
          decision_text: rated_disability['description'],
          diagnostic_code: rated_disability['diagnostic_type_code'].to_i,
          effective_date: rated_disability['effective_date'],
          rated_disability_id: 0,
          rating_decision_id: 0,
          rating_percentage: rated_disability['rating_percentage'],
          # TODO: figure out if this is important
          related_disability_date: DateTime.now
        )
      end
    DisabilityCompensation::ApiProvider::RatedDisabilitiesResponse.new(rated_disabilities:)
  end

  def decision_code_transform(decision_code_text)
    service_connected = decision_code_text&.downcase == 'Service Connected'.downcase ||
                        decision_code_text&.downcase == '1151 Granted'.downcase

    if service_connected
      'SVCCONNCTED'
    else
      'NOTSVCCON'
    end
  end
end
