# frozen_string_literal: true

require 'vye/engine'

module Vye
  def default_settings
    Settings.vye
  end

  def test_settings
    Config.load_files(
      Rails.root / 'config/settings.yml',
      Vye::Engine.root / 'config/settings/test.yml'
    ).vye
  end

  if Rails.env.test?
    alias settings test_settings
  else
    alias settings default_settings
  end

  module_function :default_settings, :test_settings, :settings
end
