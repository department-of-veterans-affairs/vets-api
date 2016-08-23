require "rails_helper"

RSpec.describe EducationBenefitsClaim, type: :model do
  let(:attributes) { { json: {}.to_json } }
  subject { described_class.new(attributes) }

  describe "redis persistence" do
    before(:each) { subject.save }

    context "save" do
      it "ttl should not expire" do
        expect(subject.ttl).to eq(-1)
      end
    end
  end

  describe "#generate_uuid" do
    it "should generate uuid before validation when it doesnt exist" do
      expect(subject.uuid.nil?).to eq(true)
      subject.valid?
      expect(subject.uuid.include?("education_benefits_claim:")).to eq(true)
    end

    it "shouldnt generate uuid when there already is one" do
      subject.uuid = "foo"
      subject.valid?
      expect(subject.uuid).to eq("foo")
    end
  end
end
