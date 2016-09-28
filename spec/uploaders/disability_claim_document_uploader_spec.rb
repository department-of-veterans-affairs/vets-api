# frozen_string_literal: true
require 'rails_helper'

RSpec.describe DisabilityClaimDocumentUploader do
  subject { described_class.new }

  describe '#store!' do
    it 'raises an error when the file is larger than 25 megabytes' do
      file = double(size: 25.megabytes + 1)
      expect { subject.store!(file) }.to raise_error(CarrierWave::UploadError)
    end
  end
end
