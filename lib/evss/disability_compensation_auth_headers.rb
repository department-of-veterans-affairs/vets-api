# frozen_string_literal: true

require 'evss/base_headers'
require 'lighthouse/base_headers'
require 'formatters/date_formatter'

module EVSS
  module HeaderInheritance
    def self.determine_parent(service_context = nil)
      case service_context
      when :poa
        EVSS::BaseHeaders
      else
        if Flipper.enabled?(:lighthouse_base_headers)
          Lighthouse::BaseHeaders
        else
          EVSS::BaseHeaders
        end
      end
    rescue => e
      Rails.logger.warn "Error checking Flipper flag: #{e.message}. Defaulting to EVSS::BaseHeaders"
      EVSS::BaseHeaders
    end
  end

  class DisabilityCompensationAuthHeaders
    def initialize(user, service_context = nil)
      @delegate = HeaderInheritance.determine_parent(service_context).new(user)
      @user = user
    end

    def method_missing(method_name, *, &)
      if @delegate.respond_to?(method_name)
        @delegate.send(method_name, *, &)
      else
        super
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      @delegate.respond_to?(method_name, include_private) || super
    end

    def kind_of?(klass)
      @delegate.is_a?(klass) || super
    end

    def is_a?(klass)
      @delegate.is_a?(klass) || super
    end

    def add_headers(auth_headers)
      auth_headers.merge(
        'va_eauth_authorization' => eauth_json
      )
    end

    private

    attr_reader :delegate, :user

    def eauth_json
      {
        authorizationResponse: {
          status: 'VETERAN',
          idType: 'SSN',
          id: @user.ssn,
          edi: @user.edipi,
          firstName: @user.first_name,
          lastName: @user.last_name,
          birthDate: Formatters::DateFormatter.format_date(@user.birth_date, :datetime_iso8601),
          gender: gender
        }
      }.to_json
    end

    def gender
      case @user.gender
      when 'F'
        'FEMALE'
      when 'M'
        'MALE'
      else
        'UNKNOWN'
      end
    end
  end
end
