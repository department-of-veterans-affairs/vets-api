# frozen_string_literal: true

module EMIS
  module Responses
  end
end

# require each response file
Dir['lib/emis/responses/get_*.rb'].each { |file| require file.gsub('lib/', '') }
require 'emis/responses/error_response'
