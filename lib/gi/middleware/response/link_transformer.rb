# frozen_string_literal: true
class LinkTransformer < Faraday::Middleware
  def call(env)
    # TODO: rewrite all links with GIDS hostname to vets-api URLs
    @app.call(env)
  end
end
