# frozen_string_literal: true

require 'banners/engine'
require 'banners/updater'
require 'banners/builder'

module Banners
  def self.build(banner_props)
    Builder.perform(banner_props)
  end

  def self.update_all
    Updater.perform
  end
end
