# frozen_string_literal: true

require 'common/client/configuration/base'

module VAProfile
  module TelephoneValidation
    module V1
      class Configuration < Common::Client::Configuration::Base
        def base_path
          Settings.va_profile.telephone_validation.base_url
        end

        def service_name
          'va_profile_telephone_validation_v1'
        end
      end
    end
  end
end