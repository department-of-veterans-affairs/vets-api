# frozen_string_literal: true

require 'lighthouse/base_headers'
require 'formatters/date_formatter'

module Lighthouse
  class AuthHeaders < Lighthouse::BaseHeaders
    attr_reader :transaction_id

    def initialize(user)
      @transaction_id = create_transaction_id
      super(user)
    end

    def to_h
      @headers ||= sanitize(
        'va_eauth_csid' => 'DSLogon',
        # TODO: Change va_eauth_authenticationmethod to vets.gov
        # once the EVSS team is ready for us to use it
        'va_eauth_authenticationmethod' => 'DSLogon',
        'va_eauth_pnidtype' => 'SSN',
        'va_eauth_assurancelevel' => @user.loa[:current].to_s,
        'va_eauth_firstName' => @user.first_name,
        'va_eauth_lastName' => @user.last_name,
        'va_eauth_issueinstant' => @user.last_signed_in&.iso8601,
        'va_eauth_dodedipnid' => @user.edipi,
        'va_eauth_birlsfilenumber' => @user.birls_id,
        'va_eauth_pid' => @user.participant_id,
        'va_eauth_pnid' => @user.ssn,
        'va_eauth_birthdate' => Formatters::DateFormatter.format_date(@user.birth_date, :datetime_iso8601),
        'va_eauth_authorization' => eauth_json,
        'va_eauth_authenticationauthority' => 'eauth',
        'va_eauth_service_transaction_id' => @transaction_id
      )
    end

    private

    def create_transaction_id
      "vagov-#{SecureRandom.uuid}"
    end

    def sanitize(headers)
      headers.transform_values! do |value|
        value.nil? ? '' : value
      end
    end

    def eauth_json
      {
        authorizationResponse: {
          status: get_status,
          idType: 'SSN',
          id: @user.ssn,
          edi: @user.edipi,
          firstName: @user.first_name,
          lastName: @user.last_name,
          birthDate: Formatters::DateFormatter.format_date(@user.birth_date, :datetime_iso8601)
        }.merge(dependent? ? get_dependent_headers : {})
      }.to_json
    end

    def get_dependent_headers
      sponsor = get_user_relationship
      return {} unless sponsor

      {
        headOfFamily: {
          id: sponsor.ssn,
          idType: 'SSN',
          edi: sponsor.edipi,
          firstName: sponsor.given_names&.first,
          lastName: sponsor.family_name,
          birthDate: Formatters::DateFormatter.format_date(sponsor.birth_date, :datetime_iso8601),
          status: 'SPONSOR'
        }
      }
    end

    def get_user_relationship
      veteran_relationships = @user.relationships&.select(&:veteran_status)
      return unless veteran_relationships.presence

      # Makes sense to give the user the ability to select the relationship eventually, for now we return
      # the first applicable relationship
      selected_relationship = veteran_relationships.first
      selected_relationship.get_full_attributes.profile
    end

    def get_status
      dependent? ? 'DEPENDENT' : 'VETERAN'
    end

    def dependent?
      @user.person_types&.include?('DEP')
    end
  end
end
