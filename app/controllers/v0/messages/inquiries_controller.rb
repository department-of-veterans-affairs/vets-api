# frozen_string_literal: true

module V0
  module Messages
    class InquiriesController < ApplicationController
      def index
        return not_implemented unless Flipper.enabled?(:get_help_messages)

        response = {
          'inquiries': [
            {
              'subject': 'Prosthetics',
              'confirmationNumber': '000-010',
              'status': 'OPEN',
              'creationTimestamp': '2020-11-01T14:58:00',
              'lastActiveTimestamp': '2020-11-04T13:00:00',
              '_links': {
                'thread': {
                  'href': '/v1/user/{:user-id}/inquiry/000-010'
                }
              }
            },
            {
              'subject': 'Eyeglasses',
              'confirmationNumber': '000-011',
              'status': 'RESOLVED',
              'creationTimestamp': '2020-10-01T14:03:00',
              'lastActiveTimestamp': '2020-11-01T09:30:00',
              '_links': {
                'thread': {
                  'href': '/v1/user/{:user-id}/inquiry/000-011'
                }
              }
            },
            {
              'subject': 'Wheelchairs',
              'confirmationNumber': '000-012',
              'status': 'CLOSED',
              'creationTimestamp': '2020-06-01T14:34:00',
              'lastActiveTimestamp': '2020-06-15T18:21:00',
              '_links': {
                'thread': {
                  'href': '/v1/user/{:user-id}/inquiry/000-012'
                }
              }
            }
          ]
        }

        render json: response, status: :ok
      end

      private

      def not_implemented
        render nothing: true, status: :not_implemented, as: :json
      end
    end
  end
end
