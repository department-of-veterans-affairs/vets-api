# frozen_string_literal: true

require 'common/models/resource'

module VAOS
  class PactTeamMember < Common::Resource
    attribute :name, Types::String
    attribute :title, Types::String
  end
end
