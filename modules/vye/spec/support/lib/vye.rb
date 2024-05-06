# frozen_string_literal: true

module Vye
  module_function

  def settings
    Config.load_files(
      Rails.root / 'config/settings.yml',
      Vye::Engine.root / 'config/settings/test.yml'
    ).vye
  end
end
