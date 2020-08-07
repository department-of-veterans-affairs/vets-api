# frozen_string_literal: true

require_relative '../../../app/services/covid_vaccine_trial/screener/form_service.rb'
require_relative '../../covid_vaccine_trial_spec_helper.rb'

RSpec.configure do |c|
  c.include CovidVaccineTrialSpecHelper
end

RSpec.describe CovidVaccineTrial::Screener::FormService do
  let(:valid)   { JSON.parse(read_fixture('valid-submission.json')) }
  let(:invalid) { JSON.parse(read_fixture('no-name-submission.json')) }

  context "JSON Schema validation" do
    describe "#valid_submission?" do
      it "returns true if the JSON is valid" do
        expect(subject.valid?(valid)).to be(true)
      end

      it "returns false if the JSON is invalid" do
        expect(subject.valid?(invalid)).to be(false)
      end
    end

    describe "#submission_errors" do
      it "returns a list of error objects if the JSON is invalid" do
        expected = [
          {
            detail: {
              'missing_keys' => [
                'fullName'
              ]
            }
          }
        ]

        expect(subject.submission_errors(invalid)).to eq(expected)
      end

      it "returns an empty list if the JSON is valid" do
        expect(subject.submission_errors(valid)).to eq([])
      end
    end
  end
end