# frozen_string_literal: true

require 'vet360/response'

module Vet360
  module ContactInformation
    class PersonResponse < Vet360::Response
      attribute :person, Hash

      attr_reader :bio

      def initialize(status, response = nil)
        # TODO - how do we want to customize the response
        @bio = response&.body&.dig('bio')
binding.pry

        super(status, person: bio)
      end

      # private

      def build_person
        Vet360::Models::Person.new(
          emails: build_emails,
          telephones: build_telephones
        )
      end

      def build_emails
        # array of email_address hashes
        bio['emails'].map { |e| build_email(e) }
      end

      def build_email(hash)
        Vet360::Models::Email.new(
          created_at: hash['create_date'],
          effective_end_date: hash['effective_end_date'],
          effective_start_date: hash['effective_start_date'],
          email_address: hash['email_address_text'],
          id: hash['email_id'],
          source_date: hash['source_date'],
          transaction_id: hash['tx_audit_id'],
          updated_at: hash['update_date']
        )
      end

      def build_telephones
        # array of telephone hashes
        bio['telephones'].map { |t| build_telephone(t) }
      end

      def build_telephone(hash)
        Vet360::Models::Telephone.new(
          area_code: hash['area_code'],
          country_code: hash['country_code'],
          created_at: hash['create_date'],
          effective_end_date: hash['effective_end_date'],
          effective_start_date: hash['effective_start_date'],
          extension: hash['phone_number_ext'],
          id: hash['telephone_id'],
          is_international: hash['international_indicator'],
          phone_number: hash['phone_number'],
          phone_type: hash['phone_type'],
          source_date: hash['source_date'],
          is_textable: hash['text_message_capable_ind'],
          transaction_id: hash['tx_audit_id'],
          is_tty: hash['tty_ind'],
          updated_at: hash['update_date'],
          is_voicemailable: hash['voice_mail_acceptable_ind']
        )
      end
    end
  end
end
