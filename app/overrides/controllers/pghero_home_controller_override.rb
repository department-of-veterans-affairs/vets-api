# frozen_string_literal: true

PgHero::HomeController.class_eval do
  unless Rails.env.development?
    http_basic_authenticate_with name: Settings.pg_hero.username,
                                 password: Settings.pg_hero.password
  end

  def check_api
    # DO NOTHING - Override PgHero before action
    # We're making some overrides for rails api-only mode
    # pghero only has support for rails-api mode = false
    # out of the box
  end
end
