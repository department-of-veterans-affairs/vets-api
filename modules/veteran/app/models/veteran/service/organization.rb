# frozen_string_literal: true

module Veteran
  module Service
    class Organization < ActiveRecord::Base
      self.primary_key = :poa
    end
  end
end
