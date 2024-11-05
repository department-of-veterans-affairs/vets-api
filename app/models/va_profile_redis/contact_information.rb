# frozen_string_literal: true

require 'va_profile/contact_information/person_response'
require 'va_profile/contact_information/service'
require 'va_profile/models/address'
require 'va_profile/models/telephone'
require 'va_profile/models/permission'
require 'common/models/redis_store'
require 'common/models/concerns/cache_aside'
require 'va_profile/configuration'

module VAProfileRedis
  # Facade for VAProfile::ContactInformation::Service. The user_serializer delegates
  # to this class through the User model.
  #
  # When a person is requested from the serializer, it returns either a cached
  # response in Redis or from the VAProfile::ContactInformation::Service.
  #
  class ContactInformation < Common::RedisStore
    include Common::CacheAside

    # Redis settings for ttl and namespacing reside in config/redis.yml
    #
    redis_config_key :va_profile_contact_info_response

    # @return [User] the user being queried in VA Profile
    #
    attr_accessor :user

    def self.for_user(user)
      contact_info      = new
      contact_info.user = user
      contact_info.populate_from_redis
      contact_info
    end

    # Returns the user's email model. In VA Profile, a user can only have one
    # email address.
    #
    # @return [VAProfile::Models::Email] The user's one email address model
    #
    def email
      return unless @user.loa3?

      value_for('emails')&.first
    end

    # Returns the user's residence. In VA Profile, a user can only have one
    # residence address.
    #
    # @return [VAProfile::Models::Address] The user's one residential address model
    #
    def residential_address
      return unless @user.loa3?

      dig_out('addresses', 'address_pou', VAProfile::Models::Address::RESIDENCE)
    end

    # Returns the user's mailing address. In VA Profile, a user can only have one
    # mailing address.
    #
    # @return [VAProfile::Models::Address] The user's one mailing address model
    #
    def mailing_address
      return unless @user.loa3?

      dig_out('addresses', 'address_pou', VAProfile::Models::Address::CORRESPONDENCE)
    end

    # Returns the user's home phone. In VA Profile, a user can only have one
    # home phone.
    #
    # @return [VAProfile::Models::Telephone] The user's one home phone model
    #
    def home_phone
      return unless @user.loa3?

      dig_out('telephones', 'phone_type', VAProfile::Models::Telephone::HOME)
    end

    # Returns the user's mobile phone. In VA Profile, a user can only have one
    # mobile phone.
    #
    # @return [VAProfile::Models::Telephone] The user's one mobile phone model
    #
    def mobile_phone
      return unless @user.loa3?

      dig_out('telephones', 'phone_type', VAProfile::Models::Telephone::MOBILE)
    end

    # Returns the user's work phone. In VA Profile, a user can only have one
    # work phone.
    #
    # @return [VAProfile::Models::Telephone] The user's one work phone model
    #
    def work_phone
      return unless @user.loa3?

      dig_out('telephones', 'phone_type', VAProfile::Models::Telephone::WORK)
    end

    # Returns the user's temporary phone. In VA Profile, a user can only have one
    # temporary phone.
    #
    # @return [VAProfile::Models::Telephone] The user's one temporary phone model
    #
    def temporary_phone
      return unless @user.loa3?

      dig_out('telephones', 'phone_type', VAProfile::Models::Telephone::TEMPORARY)
    end

    # Returns the user's fax number. In VA Profile, a user can only have one
    # fax number.
    #
    # @return [VAProfile::Models::Telephone] The user's one fax number model
    #
    def fax_number
      return unless @user.loa3?

      dig_out('telephones', 'phone_type', VAProfile::Models::Telephone::FAX)
    end

    # Returns the user's text permission. In VA Profile, a user can only have one
    # text permission.
    #
    # @return [VAProfile::Models::Permission] The user's one text permission model
    #
    def text_permission
      return unless @user.loa3?

      dig_out('permissions', 'permission_type', VAProfile::Models::Permission::TEXT)
    end

    # The status of the last VAProfile::ContactInformation::Service response,
    # or not authorized for for users < LOA 3
    #
    # @return [Integer <> String] the status of the last VAProfile::ContactInformation::Service response
    #
    def status
      return VAProfile::ContactInformation::PersonResponse::RESPONSE_STATUS[:not_authorized] unless @user.loa3?

      response.status
    end

    # @return [VAProfile::ContactInformation::PersonResponse] the response returned from
    # the redis cache.  If that is unavailable, it calls the
    # VAProfile::ContactInformation::Service#get_person endpoint.
    #
    def response
      @response ||= response_from_redis_or_service
    end

    # This method allows us to populate the local instance of a
    # VAProfileRedis::ContactInformation object with the uuid necessary
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
      return contact_info_service.get_person unless VAProfile::Configuration::SETTINGS.contact_information.cache_enabled

      do_cached_with(key: @user.uuid) do
        contact_info_service.get_person
      end
    end

    def contact_info_service
      @service ||= VAProfile::ContactInformation::Service.new @user
    end
  end
end
