# frozen_string_literal: true
module SAML
  class UserAttributes
    ## saml_response = OneLogin::RubySaml::Response
    def initialize(saml_response)
      @saml_response = saml_response
    end

    def to_hash
      attributes = @saml_response.attributes.all.to_h
      {
        first_name:     attributes['fname']&.first,
        middle_name:    attributes['mname']&.first,
        last_name:      attributes['lname']&.first,
        zip:            attributes['zip']&.first,
        email:          attributes['email']&.first,
        gender:         parse_gender(attributes['gender']&.first),
        ssn:            attributes['social']&.first&.delete('-'),
        birth_date:     attributes['birth_date']&.first,
        uuid:           attributes['uuid']&.first,
        last_signed_in: Time.current.utc,
        loa:            { current: loa_current, highest: loa_highest(attributes) }
      }
    end

    private

    def parse_gender(gender)
      return nil unless gender
      gender[0].upcase
    end

    def loa_current
      @raw_loa ||= REXML::XPath.first(@saml_response.decrypted_document, '//saml:AuthnContextClassRef')&.text
      LOA::MAPPING[@raw_loa]
    end

    def loa_highest(attributes)
      Rails.logger.warn 'LOA.highest is nil!' if (loa = attributes['level_of_assurance']&.first&.to_i).nil?
      loa_highest = loa || loa_current
      Rails.logger.warn 'LOA.highest is less than LOA.current' if loa_highest < loa_current
      [loa_current, loa_highest].max
    end
  end
end
