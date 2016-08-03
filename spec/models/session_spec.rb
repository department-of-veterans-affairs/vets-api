require "rails_helper"
require "fakeredis"

RSpec.describe Session, type: :model do
  let(:attributes) { {} }
  subject { described_class.new(attributes) }

  context "session without attributes" do
    it "expect ttl to an Integer" do
      expect(subject.ttl).to be_an(Integer)
      expect(subject.ttl).to be_between(-3600, 0)
    end

    it "assigns a token based based on default length" do
      expect(subject.token.length).to eq(described_class::DEFAULT_TOKEN_LENGTH)
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

    it "can find a saved session to redis" do
      found_session = described_class.find(subject.token)
      expect(found_session).to be_a(described_class)
      expect(found_session.token).to eq(subject.token)
    end

    it "raises a not found error if token does not exist" do
      expect { described_class.find("non-existant-token") }
        .to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
