# frozen_string_literal: true

require 'evss/base_headers'
require 'lighthouse/base_headers'
require 'formatters/date_formatter'

module EVSS
 module HeaderInheritance
   def self.determine_parent
     if Flipper.enabled?(:lighthouse_base_headers)
       Lighthouse::BaseHeaders
     else
       EVSS::BaseHeaders
     end
   rescue StandardError => e
     Rails.logger.warn "Error checking Flipper flag: #{e.message}. Defaulting to EVSS::BaseHeaders"
     EVSS::BaseHeaders
   end
 end

 class AuthHeaders
   attr_reader :transaction_id

   def initialize(user)
     @delegate = HeaderInheritance.determine_parent.new(user)
     @transaction_id = create_transaction_id
     @user = user
   end

   def to_h
     @headers ||= sanitize(
       'va_eauth_csid' => 'DSLogon',
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

   def method_missing(method_name, *args, &block)
     if @delegate.respond_to?(method_name)
       @delegate.send(method_name, *args, &block)
     else
       super
     end
   end

   def respond_to_missing?(method_name, include_private = false)
     @delegate.respond_to?(method_name, include_private) || super
   end

   def kind_of?(klass)
     @delegate.kind_of?(klass) || super
   end

   def is_a?(klass)
     @delegate.is_a?(klass) || super
   end

   private

   attr_reader :delegate, :user

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