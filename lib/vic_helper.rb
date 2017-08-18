# frozen_string_literal: true
require 'uri'
require 'base64'
require 'oj'
require 'openssl'

module VIC
  class Helper

    def self.generate_url(current_user)
      base_url = URI(Settings.vic.url)
      params = {
        "edipi" => current_user.edipi,
        "firstname" => current_user.first_name,
        "lastname" => current_user.last_name,
        "address" => current_user.va_profile&.address&.street || "",
        "city" => current_user.va_profile&.address&.city || "",
        "state" => current_user.va_profile&.address&.state || "",
        "zip" => current_user.va_profile&.address&.postal_code || "",
        "email" => current_user.email,
        "phone" => current_user.va_profile&.home_phone || "",
        "branchofservice" => "",
        "retired" => "",
        "serviceconnected" => "",
        "timestamp" => Time.now.utc.iso8601
      }
      canonical_string = Oj.dump(params)
      params["signature"] = Helper.sign(canonical_string)

      base_url.query = URI.encode_www_form(params)
      base_url.to_s
    end

    private

    def self.sign(canonical_string)
      digest = OpenSSL::Digest::SHA256.new
      Base64.urlsafe_encode64(Helper.signing_key.sign(digest,canonical_string))
    end

    def self.signing_key
      @key ||= OpenSSL::PKey::RSA.new(File.read(Settings.vic.signing_key_path))
    end

  end

  class InfoService

    def self.branch_of_service(current_user)
      
    end

    def self.retired?(current_user)

    end

    def self.service_connected_disability?(current_user)

    end

    def self.options(current_user)
      current_user.edipi ? { edipi: current_user.edipi } : { icn: current_user.icn }
    end

    def self.info_service
      @service ||= EMIS::MilitaryInformationService.new
    end
  end
end
