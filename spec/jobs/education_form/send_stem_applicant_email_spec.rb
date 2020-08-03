# frozen_string_literal: true

require 'rails_helper'

RSpec.describe EducationForm::SendStemApplicantEmail, type: :model, form: :education_benefits do
  subject { described_class.new }

  let(:claim) { create(:va10203) }
  let(:user) { create(:evss_user) }

  describe '#perform' do
    context 'when job runs' do
      it 'email is sent' do
        mail = double('mail')
        allow(StemApplicantConfirmationMailer).to receive(:build).with(claim).and_return(mail)
        expect(mail).to receive(:deliver_now)
        subject.perform(user.uuid, claim.id)
      end
    end
  end
end
