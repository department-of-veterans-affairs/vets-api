# frozen_string_literal: true

require 'common/exceptions'

class GeocodingService
  def query(street_address: '', city: '', state: '', zip: '')
    return nil unless [street_address, city, state, zip].all?(&:present?)

    address = "#{street_address} #{city} #{state} #{zip}"
    location_response = request_location(address)
    if location_response.present?
      return { lat: location_response[0], lng: location_response[1] }
    end
  end

  def request_location(address)
    query = {
      q: address,
      key: Settings.bing.key
    }
    response = Faraday.get "#{Settings.bing.base_api_url}/Locations", query
    response_body = JSON.parse(response.body)
    handle_bing_errors(response_body, response.headers)

    parse_location(response_body)
  end

  def parse_location(response_json)
    response_json.dig('resourceSets')
        &.first
        &.dig('resources')
        &.first
        &.dig('point', 'coordinates')
  end

  def handle_bing_errors(response_body, headers)
    if response_body['errors'].present? && response_body['errors'].size.positive?
      raise Common::Exceptions::BingServiceError, (response_body['errors'].flat_map { |h| h['errorDetails'] })
    elsif headers['x-ms-bm-ws-info'].to_i == 1 && empty_resource_set?(response_body)
      # https://docs.microsoft.com/en-us/bingmaps/rest-services/status-codes-and-error-handling
      raise Common::Exceptions::BingServiceError, 'Bing server overloaded'
    end
  end

  def empty_resource_set?(response_body)
    response_body['resourceSets'].size.zero? || response_body['resourceSets'][0]['estimatedTotal'].zero?
  end
end