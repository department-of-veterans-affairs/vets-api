# frozen_string_literal: true

require 'rails_helper'
require 'increase_compensation/pdf_stamper'

RSpec.describe IncreaseCompensation::PdfStamper do
  describe '#veteran_full_name' do
    it 'successfully extracts veteran name' do
      form_data = {
        'veteranFullName' => {
          'first' => 'Philip',
          'last' => 'Fry'
        }
      }
      expect(described_class.veteran_full_name(form_data)).to eq('Philip Fry')
    end
  end
end
