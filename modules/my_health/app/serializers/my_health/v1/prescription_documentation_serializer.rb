# frozen_string_literal: true
require 'digest'

module MyHealth
  module V1
    class PrescriptionDocumentationSerializer < ActiveModel::Serializer
      attributes :html

      def html
        object.html[:html]
      end

      def id
        nil
      end
    end
  end
end
