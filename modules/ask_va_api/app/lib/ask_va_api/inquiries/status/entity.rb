# frozen_string_literal: true

module AskVAApi
  module Inquiries
    module Status
      class Entity
        attr_reader :status, :id

        def initialize(info)
          @id = nil
          @status = info[:Status]
        end
      end
    end
  end
end
