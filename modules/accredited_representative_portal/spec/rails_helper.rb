# frozen_string_literal: true

require 'rails_helper'
require_relative 'spec_helper'

require File.expand_path('../../../config/environment', __dir__)

module AccreditedRepresentativePortal
  module RequestHelper
    def parsed_response
      JSON.parse(response.body)
    end
  end
end

RSpec.configure do |config|
  config.include AccreditedRepresentativePortal::RequestHelper, type: :request
end
