# frozen_string_literal: true

require 'common/client/base'

module Vet360
  module ContactInformation
    class Service < Vet360::Service
      include Common::Client::Monitoring

      configuration Vet360::ContactInformation::Configuration

      def get_person
        with_monitoring do
          # TODO: guard clause in case there is no vet360_id
          raw_response = perform(:get, @user.vet360_id)
          Vet360::ContactInformation::PersonResponse.new(raw_response.status, raw_response)
        end
      rescue StandardError => e
        handle_error(e)
      end

      def post_email(vet360_email)
        post_or_put_email(:post, vet360_email)
      end

      def put_email(vet360_email)
        post_or_put_email(:put, vet360_email)
      end

      def post_address(vet360_address)
        post_or_put_address(:post, vet360_address)
      end

      def put_address(vet360_address)
        post_or_put_address(:put, vet360_address)
      end

      private

      def post_or_put_email(method, vet360_email)
        with_monitoring do
          raw = perform(method, "emails", vet360_email.to_request)
          Vet360::ContactInformation::EmailUpdateResponse.new(raw.status, Vet360::Models::Email.from_response(raw))
        end
      rescue StandardError => e
        handle_error(e)
      end      

      def post_or_put_address(method, vet360_address)
        with_monitoring do
          raw = perform(method, "addresses", vet360_address.to_request)
          Vet360::ContactInformation::AddressUpdateResponse.new(raw.status, Vet360::Models::Address.from_response(raw))
        end
      rescue StandardError => e
        handle_error(e)
      end

    end
  end
end
