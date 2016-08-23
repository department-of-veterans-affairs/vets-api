require "rails_helper"

RSpec.describe EducationBenefitsClaim, type: :model do
  let(:attributes) { { json: {}.to_json } }
  subject { described_class.new(attributes) }

  describe "validations" do
    %w(uuid submitted_at json).each do |attr|
      it { should validate_presence_of(attr) }
    end
  end

  describe "redis persistence" do
    before(:each) { subject.save }

    context "save" do
      it "ttl should not expire" do
        expect(subject.ttl).to eq(-1)
      end
    end
  end

  describe "#generate_uuid" do
    it "should generate uuid after initialization when it doesnt exist" do
      expect(subject.uuid.include?("education_benefits_claim:")).to eq(true)
    end

    context "with uuid set in attributes" do
      let(:attributes) do
        {
          uuid: "foo"
        }
      end

      it "shouldnt generate uuid" do
        expect(subject.uuid).to eq("foo")
      end
    end
  end

  describe "#set_submitted_at" do
    it "should set the submitted_at date after initialization" do
      Timecop.freeze do
        expect(subject.submitted_at).to eq(Time.zone.now)
      end
    end

    context "with submitted_at set on init" do
      let(:time) { 1.day.ago }
      subject { described_class.new(attributes.merge(submitted_at: time)) }

      it "should not set the submitted_at" do
        expect(subject.submitted_at).to eq(time)
      end
    end
  end
end
