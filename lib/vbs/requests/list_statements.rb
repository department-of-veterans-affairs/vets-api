# frozen_string_literal: true

require_relative './base'

module VBS
  module Requests
    class ListStatements < VBS::Requests::Base
      HTTP_METHOD = :post
      PATH        = '/GetStatementsByEDIPIAndVistaAccountNumber'

      def self.schema
        {
          'type' => 'object',
          'additionalProperties' => false,
          'required' => %w[edipi vistaAccountNumbers],
          'properties' => {
            'edipi' => {
              'type' => 'string'
            },
            'vistaAccountNumbers' => {
              'type' => 'array',
              'items' => {
                'type' => 'string',
                'minLength' => 16,
                'maxLength' => 16
              }
            }
          }
        }
      end

      attr_accessor :edipi, :vista_account_numbers

      def initialize(edipi = nil, vista_account_numbers = [])
        @edipi = edipi
        @vista_account_numbers = vista_account_numbers
      end

      def data
        {
          edipi:,
          vistaAccountNumbers: vista_account_numbers
        }
      end
    end
  end
end
