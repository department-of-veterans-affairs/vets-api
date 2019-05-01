# frozen_string_literal: true

module Veteran
  # Not technically a Service Object, this is a term used by the VA internally.
  module Service
    class Organization < ApplicationRecord
      self.primary_key = :poa

      validates :poa, presence: true
    end
  end
end
