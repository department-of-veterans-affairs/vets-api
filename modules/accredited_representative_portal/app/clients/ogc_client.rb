# frozen_string_literal: true

module AccreditedRepresentativePortal
  class OGCClient
    attr_reader :config

    def initialize
      @config = setup_configuration
    end

    def find_registration_number_for_icn(icn)
      return nil if icn.blank?
      
      begin
        response = make_reg_number_request(icn)
        
        if response.status == 200 && response.body.present?
          registration_numbers = parse_registration_numbers(response.body)
          if registration_numbers.present?
            # If multiple registrations are found, how should we handle this?
            return registration_numbers.first
          end
        end
        
        nil
      rescue => e
        Rails.logger.error("Error looking up registration number for ICN: #{e.message}")
        nil
      end
    end

    def post_icn_and_registration_combination(icn, registration_number)
      return nil if icn.blank? || registration_number.blank?

      begin
        response = make_icn_reg_post_request(icn, registration_number)
        
        if response.status == 200 && response.body.present?
          # Process response if needed
          return true
        end
        
        false
      rescue => e
        Rails.logger.error("Error posting ICN and registration combination: #{e.message}")
        false
      end
    end

    private

    def make_icn_reg_post_request(icn, registration_number)
      url = config[:icn_endpoint_url] + "/#{registration_number}"
      
      headers = {
        'Content-Type' => 'application/json',
        'x-api-key' => config[:api_key]
      }
      
      payload = {
        icnNo: icn,
        registrationNo: registration_number,
        multiMatchInd: true
      }
      
      Faraday.new.post(url, payload.to_json, headers)
    end

    def make_reg_number_request(icn)
      url = [:icn_endpoint_url]
      
      headers = {
        'Content-Type' => 'application/json',
        'x-api-key' => config[:api_key]
      }
      
      payload = {
        icnNo: icn,
        multiMatchInd: true
      }
      
      Faraday.new.post(url, payload.to_json, headers)
    end

    def parse_registration_numbers(response_body)
      json_response = JSON.parse(response_body)
      json_response['registrationNumbers']
    rescue JSON::ParserError => e
      Rails.logger.error("Error parsing OGC response: #{e.message}")
      nil
    end

    def setup_configuration
      {
        api_key: api_key,
        icn_endpoint_url: icn_endpoint_url
      }
    end

    def api_key
      Settings.gclaws.accreditation.api_key
    end

    def icn_endpoint_url
      Settings.gclaws.accreditation.icn.url
    end
  end
end