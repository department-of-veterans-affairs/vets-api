# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AskService do
  describe "#post_to_xrm" do
    context "given a call" do
      it "returns zero" do
        expect(AskService.post_to_xrm).to eq(0)
      end
    end
  end
end
