# frozen_string_literal: true

module Vye
  class Vye::BdnClone < ApplicationRecord
    has_many :user_infos, dependent: :destroy
  end
end
