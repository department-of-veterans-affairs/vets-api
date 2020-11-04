# frozen_string_literal: true

module MVI
  module Responses
    # This class takes a valid ICN with an Assigning Authority ID, and
    # an ID status, and parses it to meet Vet360's icn_with_aaid design constraints.
    #
    class ICNWithAAIDParser
      attr_reader :extension

      # @param extension [String] A full ICN with an Assigning Authority ID,
      #   and an ID status (i.e. '12345678901234567^NI^200M^USVHA^P').
      #   This structure of five sections is enforced by the IdParser::ICN_REGEX.
      #   The five sections are: ID^TYPE^SOURCE^ISSUER^IDSTATUS
      #   A valid ICN will have a TYPE of 'NI', SOURCE of '200M', ISSUER of 'USVHA' and IDSTATUS of 'P'
      #
      def initialize(extension)
        @extension = extension
      end

      # Starts with a full icn_with_aaid with an ID status. For valid ID statuses, returns
      # the icn_with_aaid with the ID status removed. For invalid ID statuses, returns nil.
      #
      # @return [String] For valid case, an icn_with_aaid with the ID status removed.
      #   For example, '12345678901234567^NI^200M^USVHA'
      # @return [Nil]
      #
      def without_id_status
        return if extension.nil?
        return unless id_status == 'P'

        trim_id_status
      end

      private

      def id_status
        identifiers.last
      end

      def identifiers
        extension.split('^')
      end

      def trim_id_status
        identifiers.take(4).join('^')
      end
    end
  end
end
