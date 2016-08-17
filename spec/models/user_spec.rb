require "rails_helper"
require "fakeredis/rspec"

RSpec.describe User, type: :model do
  let(:attributes) { { uuid: "userid:123", email: "test@test.com" } }
  subject { described_class.new(attributes) }

  context "user without attributes" do
    it "expect ttl to an Integer" do
      expect(subject.ttl).to be_an(Integer)
      expect(subject.ttl).to be_between(-Float::INFINITY, 0)
    end

    it "assigns an email" do
      expect(subject.email).to eq("test@test.com")
    end

    it "assigns an uuid" do
      expect(subject.uuid).to eq("userid:123")
    end

    it "has a persisted attribute of false" do
      expect(subject.persisted?).to be_falsey
    end
  end

  describe "redis persistence" do
    before(:each) { subject.save }

    context "save" do
      it "sets persisted flag to true" do
        expect(subject.persisted?).to be_truthy
      end

      it "sets the ttl countdown" do
        expect(subject.ttl).to be_an(Integer)
        expect(subject.ttl).to be_between(0, 86_400)
      end
    end

    context "find" do
      let(:found_user) { described_class.find(subject.uuid) }

      it "can find a saved user in redis" do
        expect(found_user).to be_a(described_class)
        expect(found_user.uuid).to eq(subject.uuid)
      end

      it "expires and returns nil if user loaded from redis is invalid" do
        allow_any_instance_of(described_class).to receive(:valid?).and_return(false)
        expect(found_user).to be_nil
      end

      it "returns nil if user was not found" do
        expect(described_class.find("non-existant-uuid")).to be_nil
      end
    end

    context "destroy" do
      it "can destroy a user in redis" do
        expect(subject.destroy).to eq(1)
        expect(described_class.find(subject.uuid)).to be_nil
      end
    end
  end
end
