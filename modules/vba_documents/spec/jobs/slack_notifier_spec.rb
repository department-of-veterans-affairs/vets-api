# frozen_string_literal: true

require 'rails_helper'
#require_relative '../support/vba_document_fixtures'

RSpec.describe VBADocuments::SlackNotifier, type: :job do
  # include VBADocuments::Fixtures

  describe '#perform' do
    it 'shoots the shit with slack' do
      job = described_class.new
      job.perform
    end
  end

end

