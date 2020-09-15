# frozen_string_literal: true

require 'vet360/contact_information/person_response'
require 'vet360/contact_information/service'
require 'vet360/models/address'
require 'vet360/models/telephone'
require 'vet360/models/permission'
require 'common/models/redis_store'
require 'common/models/concerns/cache_aside'

module Vet360Redis
  # Facade for Vet360::ContactInformation::Service. The user_serializer delegates
  # to this class through the User model.
  #
  # When a person is requested from the serializer, it returns either a cached
  # response in Redis or from the Vet360::ContactInformation::Service.
  #
  class ContactInformation < Common::RedisStore
    include Common::CacheAside

    # Redis settings for ttl and namespacing reside in config/redis.yml
    #
    redis_config_key :vet360_contact_info_response

    # @return [User] the user being queried in Vet360
    #
    attr_accessor :user

    def self.for_user(user)
      contact_info      = new
      contact_info.user = user
      contact_info.populate_from_redis

      contact_info
    end

    # Returns the user's email model. In Vet360, a user can only have one
    # email address.
    #
    # @return [Vet360::Models::Email] The user's one email address model
    #
    def email
      return unless @user.loa3?

      value_for('emails')&.first
    end

    # Returns the user's residence. In Vet360, a user can only have one
    # residence address.
    #
    # @return [Vet360::Models::Address] The user's one residential address model
    #
    def residential_address
      return unless @user.loa3?

      dig_out('addresses', 'address_pou', Vet360::Models::Address::RESIDENCE)
    end

    # Returns the user's mailing address. In Vet360, a user can only have one
    # mailing address.
    #
    # @return [Vet360::Models::Address] The user's one mailing address model
    #
    def mailing_address
      return unless @user.loa3?

      dig_out('addresses', 'address_pou', Vet360::Models::Address::CORRESPONDENCE)
    end

    # Returns the user's home phone. In Vet360, a user can only have one
    # home phone.
    #
    # @return [Vet360::Models::Telephone] The user's one home phone model
    #
    def home_phone
      return unless @user.loa3?

      dig_out('telephones', 'phone_type', Vet360::Models::Telephone::HOME)
    end

    # Returns the user's mobile phone. In Vet360, a user can only have one
    # mobile phone.
    #
    # @return [Vet360::Models::Telephone] The user's one mobile phone model
    #
    def mobile_phone
      return unless @user.loa3?

      dig_out('telephones', 'phone_type', Vet360::Models::Telephone::MOBILE)
    end

    # Returns the user's work phone. In Vet360, a user can only have one
    # work phone.
    #
    # @return [Vet360::Models::Telephone] The user's one work phone model
    #
    def work_phone
      return unless @user.loa3?

      dig_out('telephones', 'phone_type', Vet360::Models::Telephone::WORK)
    end

    # Returns the user's temporary phone. In Vet360, a user can only have one
    # temporary phone.
    #
    # @return [Vet360::Models::Telephone] The user's one temporary phone model
    #
    def temporary_phone
      return unless @user.loa3?

      dig_out('telephones', 'phone_type', Vet360::Models::Telephone::TEMPORARY)
    end

    # Returns the user's fax number. In Vet360, a user can only have one
    # fax number.
    #
    # @return [Vet360::Models::Telephone] The user's one fax number model
    #
    def fax_number
      return unless @user.loa3?

      dig_out('telephones', 'phone_type', Vet360::Models::Telephone::FAX)
    end

    # Returns the user's text permission. In Vet360, a user can only have one
    # text permission.
    #
    # @return [Vet360::Models::Permission] The user's one text permission model
    #
    def text_permission
      return unless @user.loa3?

      dig_out('permissions', 'permission_type', Vet360::Models::Permission::TEXT)
    end

    # The status of the last Vet360::ContactInformation::Service response,
    # or not authorized for for users < LOA 3
    #
    # @return [Integer <> String] the status of the last Vet360::ContactInformation::Service response
    #
    def status
      return Vet360::ContactInformation::PersonResponse::RESPONSE_STATUS[:not_authorized] unless @user.loa3?

      response.status
    end

    # @return [Vet360::ContactInformation::PersonResponse] the response returned from
    # the redis cache.  If that is unavailable, it calls the
    # Vet360::ContactInformation::Service#get_person endpoint.
    #
    def response
      @response ||= response_from_redis_or_service
    end

    # This method allows us to populate the local instance of a
    # Vet360Redis::ContactInformation object with the uuid necessary
    # to perform subsequent actions on the key such as deletion.
    def populate_from_redis
      response_from_redis_or_service
    end

    private

    def value_for(key)
      value = response&.person&.send(key)

      value.presence
    end

    def dig_out(key, type, matcher)
      response_value = value_for(key)

      return if response_value.blank?

      response_value.find do |contact_info|
        contact_info.send(type) == matcher
      end
    end

    def response_from_redis_or_service
      return contact_info_service.get_person unless Settings.vet360.contact_information.cache_enabled

      do_cached_with(key: @user.uuid) do
        contact_info_service.get_person
      end
    end

    def contact_info_service
      @service ||= Vet360::ContactInformation::Service.new(@user)
    end
  end
end
