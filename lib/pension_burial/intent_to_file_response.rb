# frozen_string_literal: true

module PensionBurial
  module ApiResponse
    class IntentToFile
      attr_reader :id, :creation_date, :expration_date, :participant_id, :source, :status, :type

      def initialize(data)
        @id = data['id']
        @creation_date = data['attributes']['creationDate']
        @expiration_date = data['attributes']['expirationDate']
        @participant_id = 0
        @source = ''
        @status = data['attributes']['status']
        @type = data['attributes']['type']
      end
    end

    class IntentToFileGetResponse
      attr_reader :intent_to_file

      def initialize(data)
        @intent_to_file = [IntentToFile.new(data)]
      end
    end

    class IntentToFileCreateResponse
      attr_reader :intent_to_file

      def initialize(data)
        @intent_to_file = IntentToFile.new(data)
      end
    end
  end
end
