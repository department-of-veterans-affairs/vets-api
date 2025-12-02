# frozen_string_literal: true

require 'rails_helper'

require 'pensions/pdf_fill/section'

describe Pensions::PdfFill::Section do
  let(:section) { described_class.new }
  let(:form_data) do
    VetsJsonSchema::EXAMPLES.fetch('21P-527EZ-KITCHEN_SINK')
  end

  describe '#expand' do
    it 'raises NotImplemented' do
      expect { section.expand(form_data) }.to raise_error(NotImplementedError)
    end
  end

  describe '#expand_item' do
    it 'raises NotImplemented' do
      expect { section.expand_item(anything) }.to raise_error(NotImplementedError)
    end
  end
end
