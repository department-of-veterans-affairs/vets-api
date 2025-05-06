# frozen_string_literal: true

require 'disability_compensation/providers/rated_disabilities/rated_disabilities_provider'
require 'disability_compensation/responses/rated_disabilities_response'
require 'lighthouse/veteran_verification/service'

class LighthouseRatedDisabilitiesProvider
  include RatedDisabilitiesProvider

  # @param [string] :icn icn of the user
  def initialize(icn)
    @service = VeteranVerification::Service.new
    @icn = icn
  end

  # @param [string] lighthouse_client_id: the lighthouse_client_id requested from Lighthouse
  # @param [string] lighthouse_rsa_key_path: path to the private RSA key used to create the lighthouse_client_id
  # @return [integer] the combined disability rating
  def get_combined_disability_rating(lighthouse_client_id = nil, lighthouse_rsa_key_path = nil)
    data = get_data(lighthouse_client_id, lighthouse_rsa_key_path)
    data.dig('data', 'attributes', 'combined_disability_rating')
  end

  # @param [string] lighthouse_client_id: the lighthouse_client_id requested from Lighthouse
  # @param [string] lighthouse_rsa_key_path: path to the private RSA key used to create the lighthouse_client_id
  # @return [DisabilityCompensation::ApiProvider::RatedDisabilitiesResponse] a list of individual disability ratings
  # @option options [string] :invoker where this method was called from
  def get_rated_disabilities(lighthouse_client_id = nil, lighthouse_rsa_key_path = nil, options = {})
    data = get_data(lighthouse_client_id, lighthouse_rsa_key_path, options)
    transform(data['data']['attributes']['individual_ratings'])
  end

  # @param [string] lighthouse_client_id: the lighthouse_client_id requested from Lighthouse
  # @param [string] lighthouse_rsa_key_path: path to the private RSA key used to create the lighthouse_client_id
  # @option options [string] :invoker where this method was called from
  def get_data(lighthouse_client_id = nil, lighthouse_rsa_key_path = nil, options = {})
    @service.get_rated_disabilities(@icn, lighthouse_client_id, lighthouse_rsa_key_path, options)
  end

  def transform(data)
    rated_disabilities =
      data.map do |rated_disability|
        DisabilityCompensation::ApiProvider::RatedDisability.new(
          name: rated_disability['diagnostic_text'],
          decision_code: decision_code_transform(rated_disability['decision']),
          decision_text: rated_disability['decision'],
          diagnostic_code: rated_disability['diagnostic_type_code'].to_i,
          hyphenated_diagnostic_code: rated_disability['hyph_diagnostic_type_code'].presence&.to_i,
          effective_date: rated_disability['effective_date'],
          rated_disability_id: rated_disability['disability_rating_id'],
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
