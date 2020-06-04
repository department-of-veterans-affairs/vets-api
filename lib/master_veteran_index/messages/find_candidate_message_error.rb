# frozen_string_literal: true

require 'ox'
require_relative 'message_builder'

module MasterVeteranIndex::Messages
  class FindCandidateMessageError < MessageBuilderError
  end
end
