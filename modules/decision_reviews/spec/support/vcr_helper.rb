# frozen_string_literal: true

require 'support/vcr'
require 'support/vcr_multipart_matcher_helper'

VCR::MATCH_EVERYTHING = { match_requests_on: %i[method uri headers body] }.freeze

module VCR
  def self.all_matches
    %i[method uri body]
  end
end

VCR.configure(&:configure_rspec_metadata!)

VCR.configure do |c|
  c.before_record(:force_utf8) do |interaction|
    interaction.response.body.force_encoding('UTF-8')
  end
end
