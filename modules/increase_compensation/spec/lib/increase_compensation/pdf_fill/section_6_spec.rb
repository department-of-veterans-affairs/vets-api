# frozen_string_literal: true

require 'rails_helper'

describe IncreaseCompensation::PdfFill::Section6 do
  include PdfFill::Forms::FormHelper
  # prevents name fallback behavior from erroring
  name = {
    'first' => 'Johnny',
    'middleinitial' => 'Juan',
    'last' => 'Rico'
  }
  describe 'date fallback' do
    it 'fallsback to a generated date in none is sent with submission' do
      fallback_date = Date.current.in_time_zone('America/Chicago').strftime('%Y-%m-%d')
      s6 = described_class.new
      # Provided behavior
      data = {
        'veteranFullName' => name,
        'signatureDate' => '2025-10-29'
      }
      s6.expand(data)
      expect(data['signatureDate']).to eq({ 'year' => '2025', 'month' => '10', 'day' => '29' })

      # Fallback behavior
      data = { 'signatureDate' => '', 'veteranFullName' => name }
      s6.expand(data)
      expect(data['signatureDate']).to eq(split_date(fallback_date))
    end
  end
end
