# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Form1010cg::Attachment, type: :model do
  it 'is a FormAttachment model' do
    expect(described_class.ancestors).to include(FormAttachment)
  end
end
