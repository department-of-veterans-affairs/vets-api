# frozen_string_literal: true

module Veteran
  # Not technically a Service Object, this is a term used by the VA internally.
  module Service
    class Representative < ActiveRecord::Base
      self.primary_key = :representative_id

      validates_presence_of :poa
    end
  end
end
