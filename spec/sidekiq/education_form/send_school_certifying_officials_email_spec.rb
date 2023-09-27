# frozen_string_literal: true

require 'rails_helper'
require 'gi/client' # required for stubbing, isn't loaded normally until GIDSRedis is loaded

RSpec.describe EducationForm::SendSchoolCertifyingOfficialsEmail, type: :model, form: :education_benefits do
  subject { described_class.new }

  let(:claim) { create(:va10203) }
  let(:user) { create(:evss_user) }

  def sco_email_sent_false(less_than_six_months, facility_code)
    subject.perform(claim.id, less_than_six_months, facility_code)
    db_claim = SavedClaim::EducationBenefits::VA10203.find(claim.id)
    expect(db_claim.parsed_form['scoEmailSent']).to eq(false)
  end

  describe '#perform' do
    it 'when gi_bill_status does not have remaining_entitlement sco email sent is false' do
      sco_email_sent_false(false, '1')
    end

    context 'when no facility code is present' do
      it 'sco email sent is false' do
        sco_email_sent_false(true, nil)
      end
    end

    context 'when more than six months of entitlement remaining' do
      it 'sco email sent is false' do
        sco_email_sent_false(false, '1')
      end
    end

    context 'when institution is blank' do
      before do
        gids_response = build(:gids_response, :empty)
        allow_any_instance_of(::GI::Client).to receive(:get_institution_details_v0)
          .and_return(gids_response)
      end

      it 'sco email sent is false' do
        sco_email_sent_false(true, '1')
      end
    end

    context 'when school has changed' do
      before do
        gids_response = build(:gids_response)
        allow_any_instance_of(::GI::Client).to receive(:get_institution_details_v0)
          .and_return(gids_response)
      end

      it 'sco email sent is false' do
        form = create(:va10203, :school_changed)
        subject.perform(form.id, true, '1')
        db_claim = SavedClaim::EducationBenefits::VA10203.find(form.id)

        expect(db_claim.parsed_form['scoEmailSent']).to eq(false)
      end
    end

    context 'when neither a primary or secondary sco with an email address is found' do
      before do
        gids_response = build(:gids_response, :no_scos)
        allow_any_instance_of(::GI::Client).to receive(:get_institution_details_v0)
          .and_return(gids_response)
      end

      it 'sco email sent is false' do
        sco_email_sent_false(true, '1')
      end
    end

    context 'when all conditions are met' do
      before do
        gids_response = build(:gids_response)
        allow_any_instance_of(::GI::Client).to receive(:get_institution_details_v0)
          .and_return(gids_response)

        allow_any_instance_of(ActionMailer::MessageDelivery).to receive(:deliver_now)
      end

      it 'sco email sent is true' do
        subject.perform(claim.id, true, '1')
        db_claim = SavedClaim::EducationBenefits::VA10203.find(claim.id)
        expect(db_claim.parsed_form['scoEmailSent']).to eq(true)
      end
    end
  end
end
