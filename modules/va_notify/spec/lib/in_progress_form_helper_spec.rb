# frozen_string_literal: true

require 'rails_helper'
require 'va_notify/in_progress_form_helper'

describe VANotify::InProgressFormHelper do
  describe '#veteran_data' do
    let(:in_progress_form) { create(:in_progress_686c_form) }

    it 'returns an instance of VANotify::Veteran' do
      expect(described_class.veteran_data(in_progress_form)).to be_a VANotify::Veteran
    end
  end
end
