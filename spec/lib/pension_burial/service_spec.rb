# frozen_string_literal: true
require 'rails_helper'

RSpec.describe PensionBurial::Service do
  describe '#upload' do
    it 'should upload a file' do
      VCR.config do |c|
        c.allow_http_connections_when_no_cassette = true
      end

      described_class.new.upload
    end
  end
end
