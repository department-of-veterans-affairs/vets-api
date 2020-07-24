# frozen_string_literal: true

class AddAuthenticationHeaders
  attr_accessor :cookie

  def initialize app
    @app = app
    @cookie = ''
  end

  def call env
    binding.pry
    @app.call(env.merge('Cookie' => 'new_header'))
  end
end
