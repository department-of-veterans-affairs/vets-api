# frozen_string_literal: true

require 'common/models/resource'

module VAOS
  class PactTeam < Common::Resource
    attribute :team_sid, Types::String
    attribute :team_name, Types::String
    attribute :staff, Types::Strict::Array.of(Types.Constructor(VAOS::PactTeamMember))
  end
end
