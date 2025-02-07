# # frozen_string_literal: true
#
# require 'evss/response'
# require 'evss/intent_to_file/intent_to_file'
#
# module EVSS
#   module IntentToFile
#     ##
#     # Model for an ITF response containing a list of intents to file
#     #
#     # @param status [Integer] the HTTP status code
#     #
#     # @!attribute intent_to_file
#     #   @return [Array[EVSS::IntentToFile::IntentToFile]] An array of intents to file
#     class IntentToFilesResponse < EVSS::Response
#       attribute :intent_to_file, Array[EVSS::IntentToFile::IntentToFile]
#
#       def initialize(status, response = nil)
#         super(status, response.body) if response
#       end
#     end
#   end
# end
