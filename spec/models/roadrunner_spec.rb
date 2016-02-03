require "rails_helper"

# This is an example spec. Delete it when you're ready to start.
describe Roadrunner do
  let(:roadrunner) { Roadrunner.new }

  describe "#greeting" do
    context "when no arguments passed" do
      subject { roadrunner.greeting }
      it { is_expected.to eq "beep beep" }
    end

    context "when number of times is passed" do
      subject { roadrunner.greeting(3) }
      it { is_expected.to eq "beep beep, beep beep, beep beep" }
    end
  end
end
