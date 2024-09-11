# frozen_string_literal: true

require 'common/models/resource'

module Mobile
  module V0
    class AllergyIntolerance::Note < Common::Resource
      class AuthorReference < Common::Resource
        attribute :reference, Types::String
        attribute :display, Types::String
      end

      attribute :author_reference, AuthorReference
      attribute :time, Types::DateTime
      attribute :text, Types::String
    end
  end
end
