# frozen_string_literal: true

require 'common/exceptions/base_error'

# TO-DO: Remove this error after transition of LTS to 24/7 availability and associated lines
# in exceptions.en.yml
module BenefitsEducation
  ##
  # Custom error for when the user is attempting to access the service
  # outside of working hours.  The service proxies to a service which
  # has nightly downtime
  class OutsideWorkingHours < Common::Exceptions::BaseError
    ##
    # @return [Array[Common::Exceptions::SerializableError]] An array containing the error
    #
    def errors
      [Common::Exceptions::SerializableError.new(i18n_data)]
    end

    ##
    # @return [String] The i18n key
    #
    def i18n_key
      'lighthouse.benefits_education.outside_working_hours'
    end
  end
end
