require "rails_helper"

RSpec.describe EducationForm::CreateDailySpoolFiles, type: :model, form: :education_benefits do
  subject { described_class.new }

  let(:application) do
    {
      fullName: {
        first: "Mark",
        last: "Olson"
      }
    }
  end

  context "#format_application" do
    it "uses conformant sample data in the tests" do
      expect(application).to match_vets_schema("edu-benefits-schema")
    end
    # TODO: Does it make sense to check against a known-good submission? Probably.
    it "formats a 22-1990 submission in textual form" do
      result = subject.format_application(form: "CH33_30", fullName: { first: "Mark", last: "Olson" })
      expect(result).to include("*INIT*\nMARK\n\nOLSON")
      expect(result).to include("Name:   Mark Olson")
    end
  end

  it "writes out spool files" do
    expect(Tempfile).to receive(:create).once # should be 4 times by the time we're done
    subject.run
  end
end
