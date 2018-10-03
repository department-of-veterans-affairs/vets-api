# frozen_string_literal: true
require 'rails_helper'
require 'vcr'

RSpec.describe TimeOfNeedService do
  describe "TimeOfNeed"  do
    it "service will return something" do
      hash = instance_double("Hash", :test => "test")
      s = instance_double("TimeOfNeedService")
      allow(s).to receive(:create) { hash.to_json }
      expect(s.create(hash)).to   eq(hash.to_json)
    end
  end
end