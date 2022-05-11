# frozen_string_literal: true

require 'digest'

module MyHealth
  module V1
    class EligibleDataClassesSerializer < ActiveModel::Serializer
      type 'eligible_data_classes'
      attribute :data_classes

      def data_classes
        object.map(&:name)
      end

      def id
        nil
      end
    end
  end
end
