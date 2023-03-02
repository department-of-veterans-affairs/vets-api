# frozen_string_literal: true

require 'rails_helper'

module AppealsApi
  module PdfConstruction
    module SupplementalClaim
      module V3
        describe FormFields do
          let(:form_fields) { described_class.new }

          described_class::FIELD_NAMES.each do |name, expected|
            describe "##{name}" do
              it { expect(form_fields.send(name)).to eq expected }
            end
          end
        end
      end
    end
  end
end
