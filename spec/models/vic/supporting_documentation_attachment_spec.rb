# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VIC::SupportingDocumentationAttachment do
  describe '#get_file' do
    let!(:attachment) do
      create(:supporting_documentation_attachment)
    end

    it 'should use the new filename to get the file' do
      ProcessFileJob.drain
      expect(attachment.get_file.exists?).to eq(true)
    end
  end
end
