# frozen_string_literal: true

require 'ox'
require_relative 'message_builder'

module MVI
  module Messages
    class FindCandidateMessageError < MessageBuilderError
    end
  end
end
