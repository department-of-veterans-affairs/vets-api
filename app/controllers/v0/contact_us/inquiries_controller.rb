# frozen_string_literal: true

module V0
  module ContactUs
    class InquiriesController < ApplicationController
      service_tag 'deprecated'

      skip_before_action :authenticate, only: :create

      def index
        return not_implemented unless Flipper.enabled?(:get_help_messages)

        render json: STUB_RESPONSE, status: :ok
      end

      def create
        return not_implemented unless Flipper.enabled?(:get_help_ask_form)

        claim = SavedClaim::Ask.new(form: form_submission)

        validate!(claim)

        render json: {
          confirmationNumber: '0000-0000-0000',
          dateSubmitted: DateTime.now.utc.strftime('%m-%d-%Y')
        }, status: :created
      end

      private

      def form_submission
        params.require(:inquiry).require(:form)
      end

      def validate!(claim)
        raise Common::Exceptions::ValidationErrors, claim unless claim.valid?
      end

      def not_implemented
        render nothing: true, status: :not_implemented, as: :json
      end

      STUB_RESPONSE = {
        inquiries: [
          {
            subject: 'Prosthetics',
            confirmationNumber: '000-010',
            status: 'OPEN',
            creationTimestamp: '2020-11-01T14:58:00+01:00',
            lastActiveTimestamp: '2020-11-04T13:00:00+01:00',
            links: {
              thread: {
                href: '/v1/user/{:user-id}/inquiry/000-010'
              }
            }
          },
          {
            subject: 'Eyeglasses',
            confirmationNumber: '000-011',
            status: 'RESOLVED',
            creationTimestamp: '2020-10-01T14:03:00+01:00',
            lastActiveTimestamp: '2020-11-01T09:30:00+01:00',
            links: {
              thread: {
                href: '/v1/user/{:user-id}/inquiry/000-011'
              }
            }
          },
          {
            subject: 'Wheelchairs',
            confirmationNumber: '000-012',
            status: 'CLOSED',
            creationTimestamp: '2020-06-01T14:34:00+01:00',
            lastActiveTimestamp: '2020-06-15T18:21:00+01:00',
            links: {
              thread: {
                href: '/v1/user/{:user-id}/inquiry/000-012'
              }
            }
          }
        ]
      }.freeze
    end
  end
end
