# frozen_string_literal: true

require_relative 'base'
require_relative 'attachment'

module CARMA
  module Models
    class Attachments < Base
      attr_reader   :response,
                    :has_errors

      attr_accessor :all,
                    :carma_case_id,
                    :veteran_first_name,
                    :veteran_last_name

      def initialize(carma_case_id, veteran_first_name, veteran_last_name)
        @carma_case_id        = carma_case_id
        @veteran_first_name   = veteran_first_name
        @veteran_last_name    = veteran_last_name
        @all                  = []
      end

      def add(document_type, local_path)
        all << CARMA::Models::Attachment.new(
          carma_case_id:,
          document_type:,
          file_path: local_path,
          veteran_name: {
            first: veteran_first_name,
            last: veteran_last_name
          }
        )

        self
      end

      def to_request_payload
        raise 'must have at least one attachment' if all.empty?

        {
          'records' => all.map(&:to_request_payload)
        }
      end

      def to_hash
        {
          has_errors:,
          data: all.map(&:to_hash)
        }
      end
    end
  end
end
