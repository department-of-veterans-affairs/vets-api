# frozen_string_literal: true

module Veteran
  module Service
    class Representative < ActiveRecord::Base
      self.primary_key = :representative_id

      validates_presence_of :poa
    end
  end
end
