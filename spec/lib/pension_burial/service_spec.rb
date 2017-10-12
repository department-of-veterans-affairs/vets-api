# frozen_string_literal: true
require 'rails_helper'

RSpec.describe PensionBurial::Service do
  describe '#upload' do
    it 'should upload a file' do
      described_class.new.upload
    end
  end
end
