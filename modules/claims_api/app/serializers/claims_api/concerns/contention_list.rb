# frozen_string_literal: true

module ClaimsApi
  module Concerns
    module ContentionList
      extend ActiveSupport::Concern

      included do
        attribute :contention_list do |object|
          object.data['contention_list']
        end
      end
    end
  end
end
