# frozen_string_literal: true

require 'rails_helper'
require 'support/controller_spec_helper'

RSpec.describe V0::EducationBenefitsClaimsController, type: :controller do
  it_behaves_like 'a controller that deletes an InProgressForm 22-1990', 'education_benefits_claim', 'va1990', '22-1990'
  it_behaves_like 'a controller that deletes an InProgressForm 22-1995', 'education_benefits_claim', 'va1995', '22-1995'

  describe '#create' do
    context 'with a valid 1995S form' do
      let(:form) { build(:va1995s) }
      let(:param_name) { :education_benefits_claim }
      let(:form_id) { '22-1995S' }

      context 'with a user' do
        let(:user) { create(:user) }

        it 'deletes the "in progress form"' do
          create(:in_progress_form, user_uuid: user.uuid, form_id: '22-1995')
          expect(controller).to receive(:clear_saved_form).with('22-1995').and_call_original
          sign_in_as(user)
          expect { post(:create, params: { param_name => { form: form.form } }) }
            .to change(InProgressForm, :count).by(-1)
        end
      end
    end
  end
end
