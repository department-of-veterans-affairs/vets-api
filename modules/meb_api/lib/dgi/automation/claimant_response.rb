# frozen_string_literal: true

require 'dgi/response'

module MebApi
  module DGI
    module Automation
      class ClaimantResponse < MebApi::DGI::Response
        attribute :claimant_id, Integer
        attribute :suffix, String
        attribute :date_of_birth, String
        attribute :first_name, String
        attribute :last_name, String
        attribute :middle_name, String
        attribute :notification_method, String
        attribute :preferred_contact, String
        attribute :address_line_1, String
        attribute :address_line_2, String
        attribute :city, String
        attribute :zipcode, String
        attribute :address_type, String
        attribute :email_address, String
        attribute :mobile_phone_number, String
        attribute :home_phone_number, String
        attribute :country_code, String
        attribute :state_code, String

        def initialize(status, response = nil)
          claimant_response = response&.body&.fetch('claimant')
          contact_info = claimant_response&.fetch('contact_info')
          attributes = format_attribute(claimant_response, contact_info)
          super(status, attributes)
        end

        private

        def format_attribute(claimant_response, contact_info)
          {
            claimant_id: claimant_response&.fetch('claimant_id'),
            suffix: claimant_response&.fetch('suffix'),
            date_of_birth: claimant_response&.fetch('date_of_birth'),
            first_name: claimant_response&.fetch('first_name'),
            last_name: claimant_response&.fetch('last_name'),
            middle_name: claimant_response&.fetch('middle_name'),
            notificaiton_method: claimant_response&.fetch('notification_method'),
            preferred_contact: claimant_response&.fetch('preferred_contact'),
            address_line_1: contact_info&.fetch('address_line1'),
            address_line_2: contact_info&.fetch('address_line2'),
            city: contact_info&.fetch('city'),
            zipcode: contact_info&.fetch('zipcode'),
            email_address: contact_info&.fetch('email_address'),
            address_type: contact_info&.fetch('address_type'),
            mobile_phone_number: contact_info&.fetch('mobile_phone_number'),
            home_phone_number: contact_info&.fetch('home_phone_number'),
            country_code: contact_info&.fetch('country_code'),
            state_code: contact_info&.fetch('state_code')
          }
        end
      end
    end
  end
end
