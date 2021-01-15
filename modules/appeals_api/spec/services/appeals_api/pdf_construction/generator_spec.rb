# frozen_string_literal: true

require 'rails_helper'

describe AppealsApi::PdfConstruction::Generator do
  let(:appeal) { create(:notice_of_disagreement) }

  describe "#generate" do
    it "returns a pdf path" do
      result = described_class.new(appeal).generate

      expect(result[-4..-1]).to eq('.pdf')
    end
  end
end
