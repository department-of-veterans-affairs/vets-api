# frozen_string_literal: true

require 'rails_helper'
require 'gi/client' # required for stubbing, isn't loaded normally until GIDSRedis is loaded

RSpec.describe EducationForm::SendSchoolCertifyingOfficialsEmail, type: :model, form: :education_benefits do
  subject { described_class.new }

  let(:claim) { create(:va10203) }
  let(:user) { create(:evss_user) }

  def sco_email_sent_false
    subject.perform(user.uuid, claim.id)
    db_claim = SavedClaim::EducationBenefits::VA10203.find(claim.id)
    expect(db_claim.parsed_form['scoEmailSent']).to eq(false)
  end

  describe '#perform' do
    context 'when gi_bill_status does not have remaining_entitlement' do
      before do
        gi_bill_status = build(:gi_bill_status_response, remaining_entitlement: nil)
        allow_any_instance_of(EVSS::GiBillStatus::Service).to receive(:get_gi_bill_status)
          .and_return(gi_bill_status)
      end

      it 'sco email sent is false' do
        sco_email_sent_false
      end
    end

    context 'when no facility code is present' do
      before do
        gi_bill_status = build(:gi_bill_status_response, enrollments: [])
        allow_any_instance_of(EVSS::GiBillStatus::Service).to receive(:get_gi_bill_status)
          .and_return(gi_bill_status)
      end

      it 'sco email sent is false' do
        sco_email_sent_false
      end
    end

    context 'when more than six months of entitlement remaining' do
      before do
        remaining_entitlement = { months: 10, days: 12 }

        gi_bill_status = build(:gi_bill_status_response, remaining_entitlement: remaining_entitlement)
        allow_any_instance_of(EVSS::GiBillStatus::Service).to receive(:get_gi_bill_status)
          .and_return(gi_bill_status)

        gids_response = build(:gids_response)
        allow_any_instance_of(::GI::Client).to receive(:get_institution_details)
          .and_return(gids_response)
      end

      it 'sco email sent is false' do
        sco_email_sent_false
      end
    end

    context 'when institution is blank' do
      before do
        gi_bill_status = build(:gi_bill_status_response)
        allow_any_instance_of(EVSS::GiBillStatus::Service).to receive(:get_gi_bill_status)
          .and_return(gi_bill_status)

        gids_response = build(:gids_response, :empty)
        allow_any_instance_of(::GI::Client).to receive(:get_institution_details)
          .and_return(gids_response)
      end

      it 'sco email sent is false' do
        sco_email_sent_false
      end
    end

    context 'when school has changed' do
      before do
        gi_bill_status = build(:gi_bill_status_response)
        allow_any_instance_of(EVSS::GiBillStatus::Service).to receive(:get_gi_bill_status)
          .and_return(gi_bill_status)

        gids_response = build(:gids_response)
        allow_any_instance_of(::GI::Client).to receive(:get_institution_details)
          .and_return(gids_response)
      end

      it 'sco email sent is false' do
        form = create(:va10203, :school_changed)
        subject.perform(user.uuid, form.id)
        db_claim = SavedClaim::EducationBenefits::VA10203.find(form.id)

        expect(db_claim.parsed_form['scoEmailSent']).to eq(false)
      end
    end

    context 'when neither a primary or secondary sco with an email address is found' do
      before do
        gi_bill_status = build(:gi_bill_status_response)
        allow_any_instance_of(EVSS::GiBillStatus::Service).to receive(:get_gi_bill_status)
          .and_return(gi_bill_status)

        gids_response = build(:gids_response, :no_scos)
        allow_any_instance_of(::GI::Client).to receive(:get_institution_details)
          .and_return(gids_response)
      end

      it 'sco email sent is false' do
        sco_email_sent_false
      end
    end

    context 'when all conditions are met' do
      before do
        allow(Flipper).to receive(:enabled?).with(:stem_applicant_email, anything).and_return(true)

        gi_bill_status = build(:gi_bill_status_response)
        allow_any_instance_of(EVSS::GiBillStatus::Service).to receive(:get_gi_bill_status)
          .and_return(gi_bill_status)

        gids_response = build(:gids_response)
        allow_any_instance_of(::GI::Client).to receive(:get_institution_details)
          .and_return(gids_response)

        allow_any_instance_of(ActionMailer::MessageDelivery).to receive(:deliver_now)
      end

      it 'sco email sent is true' do
        subject.perform(user.uuid, claim.id)
        db_claim = SavedClaim::EducationBenefits::VA10203.find(claim.id)
        expect(db_claim.parsed_form['scoEmailSent']).to eq(true)
      end
    end
  end
end
