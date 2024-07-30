# frozen_string_literal: true

module RuboCop
  module Cops
    class AmsSerializer < RuboCop::Cop::Base
      MSG = 'Use JSONAPI::Serializer instead of ActiveModel::Serializer'

      def_node_matcher :active_model_serializer?, <<~PATTERN
        (class
          (const _ _)
          {
            (const (const {nil? (cbase)} :ActiveModel) :Serializer)
            (const (const (const {nil? (cbase)} :ActiveModel) :Serializer) :CollectionSerializer)
          }
          ...
        )
      PATTERN

      def on_class(node)
        add_offense(node.children[1]) if active_model_serializer?(node)
      end
    end
  end
end
