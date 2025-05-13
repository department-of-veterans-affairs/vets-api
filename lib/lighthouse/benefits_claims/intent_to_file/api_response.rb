# frozen_string_literal: true

module BenefitsClaims
  module IntentToFile
    module ApiResponse
      class IntentToFileResponse
        attr_reader :id, :creation_date, :expiration_date, :participant_id, :source, :status, :type

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

      class GET
        attr_reader :intent_to_file

        def initialize(data)
          @intent_to_file = [IntentToFileResponse.new(data)]
        end
      end

      class POST
        attr_reader :intent_to_file

        def initialize(data)
          @intent_to_file = IntentToFileResponse.new(data)
        end
      end
    end
  end
end
