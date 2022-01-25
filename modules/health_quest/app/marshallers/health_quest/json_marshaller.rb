# frozen_string_literal: true

##
# An object for converting a given Hash to JSON string and back to a Hash again
#
module HealthQuest
  class JsonMarshaller
    ##
    # Method for converting a given object to a JSON string
    #
    # @param obj [Hash]
    # @return [String]
    #
    def self.dump(obj)
      obj.to_json
    end

    ##
    # Method for converting a given JSON string to a Hash
    #
    # @param attribute [String]
    # @return [Hash]
    #
    def self.load(attribute)
      JSON.parse(attribute) if attribute.present?
    end
  end
end
