# frozen_string_literal: true

module Veteran
  module Accreditation
    class BaseRepresentativeSerializer < ActiveModel::Serializer
      def distance
        object.distance / Veteran::Service::Constants::METERS_PER_MILE
      end
    end
  end
end
