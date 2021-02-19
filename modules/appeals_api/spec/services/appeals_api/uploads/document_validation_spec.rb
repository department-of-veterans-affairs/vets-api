# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::Uploads::DocumentValidation do

  describe '#validate' do
    let(:document) do
      { 'document': Rack::Test::UploadedFile.new("#{::Rails.root}/modules/appeals_api/spec/fixtures/expected_10182_extra.pdf") }
    end

    context 'when supported file uploaded (100MB 11"x11" PDF)' do

    end

    context 'when non-pdf uploaded' do

    end

    context 'when file size is too large' do

    end

    context 'when page dimensions are too large' do

    end
  end
end

