# frozen_string_literal: true

module Veteran
  module Service
    class Representative < ActiveRecord::Base
      self.primary_key = :representative_id
    end
  end
end