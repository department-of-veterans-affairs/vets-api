# frozen_string_literal: true

require 'banners/engine'
require 'banners/updater'
require 'banners/builder'

module Banners
  def self.build
    Builder.perform
  end

  def self.update
    Updater.perform
  end
end
