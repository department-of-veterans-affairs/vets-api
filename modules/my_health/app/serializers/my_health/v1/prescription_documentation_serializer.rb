# frozen_string_literal: true
require 'digest'

module MyHealth
  module V1
    class PrescriptionDocumentationSerializer < ActiveModel::Serializer
      attributes :data

      def id
        Digest::SHA256.hexdigest(object.data.to_s)
      end
    end
  end
end
