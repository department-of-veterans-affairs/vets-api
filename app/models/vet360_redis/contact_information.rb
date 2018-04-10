# frozen_string_literal: true

require 'vet360/contact_information/person_response'
require 'common/models/redis_store'
require 'common/models/concerns/cache_aside'

module Vet360Redis
  class ContactInformation < Common::RedisStore
    include Common::CacheAside

    redis_config_key :vet360_contact_info_response

    attr_accessor :user

    def self.for_user(user)
      contact_info      = new
      contact_info.user = user

      contact_info
    end

    def email
      return unless @user.loa3?

      value_for('emails')&.first
    end

    def address
      return unless @user.loa3?

      dig_out('addresses', 'address_pou', Vet360::Models::Address::RESIDENCE)
    end

    def mailing_address
      return unless @user.loa3?

      dig_out('addresses', 'address_pou', Vet360::Models::Address::CORRESPONDENCE)
    end

    def home_phone
      return unless @user.loa3?

      dig_out('telephones', 'phone_type', Vet360::Models::Telephone::HOME)
    end

    def mobile_phone
      return unless @user.loa3?

      dig_out('telephones', 'phone_type', Vet360::Models::Telephone::MOBILE)
    end

    def work_phone
      return unless @user.loa3?

      dig_out('telephones', 'phone_type', Vet360::Models::Telephone::WORK)
    end

    def temporary_phone
      return unless @user.loa3?

      dig_out('telephones', 'phone_type', Vet360::Models::Telephone::TEMPORARY)
    end

    def fax
      return unless @user.loa3?

      dig_out('telephones', 'phone_type', Vet360::Models::Telephone::FAX)
    end

    def status
      return Vet360::ContactInformation::PersonResponse::RESPONSE_STATUS[:not_authorized] unless @user.loa3?

      response.status
    end

    def response
      @response ||= response_from_redis_or_service
    end

    private

    def value_for(key)
      value = response&.person&.dig(key.to_sym)

      value.present? ? value : nil
    end

    def dig_out(key, type, matcher)
      response_value = value_for(key)

      return if response_value.blank?

      response_value.find do |address|
        address.send(type) == matcher
      end
    end

    def response_from_redis_or_service
      do_cached_with(key: @user.uuid) do
        contact_info_service.get_person
      end
    end

    def contact_info_service
      @service ||= Vet360::ContactInformation::Service.new(@user)
    end
  end
end
