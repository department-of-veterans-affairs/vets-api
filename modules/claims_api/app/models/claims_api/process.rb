# frozen_string_literal: true

module ClaimsApi
  class Process < ApplicationRecord
    belongs_to :processable, polymorphic: true
  end
end
