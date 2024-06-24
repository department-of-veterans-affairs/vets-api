# frozen_string_literal: true

module AskVAApi
  module BranchOfService
    class Serializer
      include JSONAPI::Serializer
      set_type :branch_of_service

      attributes :code, :description
    end
  end
end
