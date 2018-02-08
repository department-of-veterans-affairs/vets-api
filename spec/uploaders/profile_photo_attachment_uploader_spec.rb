# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ProfilePhotoAttachmentUploader do
  context 'in production' do
    it 'should not set aws_acl to public-read' do
      expect(Rails.env).to receive(:production?).and_return(true)
      allow_any_instance_of(described_class).to receive(:set_aws_config)
      uploader = described_class.new(SecureRandom.hex(32), nil)

      expect(uploader.aws_acl).not_to eq('public-read')
    end
  end
end
