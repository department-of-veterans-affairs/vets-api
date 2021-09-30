# frozen_string_literal: true

module Mobile
  module V0
    class Users < ApplicationRecord
      validates :icn, presence: true
    end
  end
end
