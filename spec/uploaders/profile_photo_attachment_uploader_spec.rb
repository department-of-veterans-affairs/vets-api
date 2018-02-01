# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProfilePhotoAttachmentUploader do
  context 'in production' do
    it 'should set aws_acl to public-read' do
      expect(Rails.env).to receive(:production?).and_return(true)
      uploader = described_class.new(SecureRandom.uuid)

      expect(uploader.aws_acl).to eq('public-read')
    end
  end
end
