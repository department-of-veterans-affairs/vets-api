require "rails_helper"

RSpec.describe EducationForm::CreateDailySpoolFiles, type: :model, form: :education_benefits do
  subject { described_class.new }

  let(:application_1606) do
    {
      chapter1606: true,
      fullName: {
        first: "Mark",
        last: "Olson"
      },
      gender: "M",
      birthday: "03/07/1985",
      socialSecurityNumber: "111223333",
      address: {
        country: "USA",
        state: "WI",
        zipcode: "53130",
        street: "123 Main St",
        city: "Milwaukee"
      },
      phone: "5551110000",
      emergencyContact: {
        fullName: {
          first: "Sibling",
          last: "Olson"
        },
        sameAddressAndPhone: true
      },
      bankAccount: {
        accountType: "checking",
        bankName: "First Bank of JSON",
        routingNumber: "123456789",
        accountNumber: "88888888888"
      },
      previouslyFiledClaimWithVa: false,
      previouslyAppliedWithSomeoneElsesService: false,
      alreadyReceivedInformationPamphlet: true,
      schoolName: "FakeData University",
      schoolAddress: {
        country: "USA",
        state: "MD",
        zipcode: "21231",
        street: "111 Uni Drive",
        city: "Baltimore"
      },
      educationStartDate: "08/29/2016",
      educationalObjective: "...",
      courseOfStudy: "History",
      educationType: {
        college: true,
        testReimbursement: true
      },
      currentlyActiveDuty: false,
      terminalLeaveBeforeDischarge: false,
      highSchoolOrGedCompletionDate: "06/06/2010",
      nonVaAssistance: false,
      guardsmenReservistsAssistance: false,

      additionalContributions: false,
      activeDutyKicker: false,
      reserveKicker: false,
      serviceBefore1977: false,
      # rubocop:disable LineLength
      remarks: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Proin sit amet ullamcorper est, in interdum velit. Cras purus orci, varius eget efficitur nec, dapibus id risus. Donec in pellentesque enim. Proin sagittis, elit nec consequat malesuada, nibh justo luctus enim, ac aliquet lorem orci vel neque. Ut eget accumsan ipsum. Cras sed venenatis massa. Duis odio urna, laoreet quis ante sed, facilisis congue purus. Etiam semper facilisis luctus. Class aptent taciti sociosqu ad litora torquent per conubia nostra, per inceptos himenaeos. Etiam blandit eget nibh at ornare. Sed non porttitor dui. Proin ornare magna diam, ut lacinia magna accumsan euismod.

      Phasellus et nisl id lorem feugiat molestie. Aliquam molestie,
      nulla eu fringilla finibus, massa lectus varius quam, quis ornare
      sem lorem lacinia dui. Integer consequat non arcu convallis mollis.
      Vivamus magna turpis, pharetra non eros at, feugiat rutrum nisl.
      Maecenas eros tellus, blandit id libero sed, imperdiet fringilla
      eros. Nulla vel tortor vel neque fermentum laoreet id vitae ex.
      Mauris posuere lorem tellus. Pellentesque at augue arcu.
      Vestibulum aliquam urna ac est lacinia, eu congue nisi tempor.
      "
      # rubocop:enable LineLength
    }
  end

  context "#format_application" do
    it "uses conformant sample data in the tests" do
      expect(application_1606).to match_vets_schema("edu-benefits-schema")
    end

    # TODO: Does it make sense to check against a known-good submission? Probably.
    it "formats a 22-1990 submission in textual form" do
      result = subject.format_application(application_1606.merge(form: "CH1606"))
      # puts result
      expect(result).to include("*INIT*\nMARK\n\nOLSON")
      expect(result).to include("Name:   Mark Olson")
      expect(result).to include("EDUCATION BENEFIT BEING APPLIED FOR: Chapter 1606")
    end
  end

  it "writes out spool files" do
    expect(Tempfile).to receive(:create).once # should be 4 times by the time we're done
    subject.run
  end
end
