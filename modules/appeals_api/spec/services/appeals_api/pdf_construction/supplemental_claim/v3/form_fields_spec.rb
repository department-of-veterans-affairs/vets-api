# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::PdfConstruction::SupplementalClaim::V3::FormFields do
  let(:form_fields) { described_class.new }

  described_class::FIELD_NAMES.each do |name, expected|
    describe "##{name}" do
      it { expect(form_fields.send(name)).to eq expected }
    end
  end
end
