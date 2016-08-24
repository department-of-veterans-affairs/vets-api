require "rails_helper"

RSpec.describe EducationForm::CreateDailySpoolFiles, type: :model do
  subject { described_class.new }

  context "#format_application" do
    # TODO: Does it make sense to check against a known-good submission? Probably.
    it "formats a 22-1990 submission in textual form" do
      result = subject.format_application(first_name: "Mark", last_name: "Olson")
      expect(result).to include("*INIT*\nMARK\n\nOLSON")
      expect(result).to include("Name:   Mark Olson")
    end
  end

  it "writes out spool files" do
    expect(Tempfile).to receive(:create).once # should be 4 times by the time we're done
    subject.run
  end
end
