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
end
