require "rails_helper"

RSpec.describe V0::EducationBenefitsClaimsController, type: :controller do
  describe "POST create" do
    subject do
      post(:create, params)
    end

    context "with valid params" do
      let(:params) do
        {
          education_benefits_claim: {
            form: { chapter33: true }
          }
        }
      end

      it "should create a new model" do
        expect { subject }.to change { EducationBenefitsClaim.count }.by(1)
        expect(EducationBenefitsClaim.last.form["chapter33"]).to eq(true)
      end

      it "should render json of the new model" do
        subject
        expect(response.body).to eq(EducationBenefitsClaim.last.to_json)
      end
    end
  end
end
