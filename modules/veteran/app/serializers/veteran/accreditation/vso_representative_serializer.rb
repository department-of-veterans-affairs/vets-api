# frozen_string_literal: true

module Veteran
  module Accreditation
    class VSORepresentativeSerializer < BaseRepresentativeSerializer
      attribute :organization_names

      delegate :organization_names, to: :object
    end
  end
end
