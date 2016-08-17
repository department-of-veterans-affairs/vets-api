require "rails_helper"
require "fakeredis_helper"

RSpec.describe Session, type: :model do
  let(:attributes) { {} }
  subject { described_class.new(attributes) }

  context "session without attributes" do
    it "expect ttl to an Integer" do
      expect(subject.ttl).to be_an(Integer)
      expect(subject.ttl).to be_between(-Float::INFINITY, 0)
    end

    it "assigns a token having length 40" do
      expect(subject.token.length).to eq(40)
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
        expect(subject.ttl).to be_between(0, 3600)
      end
    end

    context "find" do
      let(:found_session) { described_class.find(subject.token) }

      it "can find a saved session in redis" do
        expect(found_session).to be_a(described_class)
        expect(found_session.token).to eq(subject.token)
      end

      it "expires and returns nil if session loaded from redis is invalid" do
        allow_any_instance_of(described_class).to receive(:valid?).and_return(false)
        expect(found_session).to be_nil
      end

      it "returns nil if session was not found" do
        expect(described_class.find("non-existant-token")).to be_nil
      end
    end

    context "destroy" do
      it "can destroy a session in redis" do
        expect(subject.destroy).to eq(1)
        expect(described_class.find(subject.token)).to be_nil
      end
    end
  end
end
