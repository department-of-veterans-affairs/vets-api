# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ch31SubmissionsReportMailer, type: %i[mailer aws_helpers] do
  describe '#build' do
    context 'with some sample claims', run_at: '2017-07-27 00:00:00' do
      let!(:vre_claim_1) do
        create(:veteran_readiness_employment_claim, updated_at: '2017-07-26 00:00:00 UTC')
      end

      let!(:vre_claim_2) do
        create(:veteran_readiness_employment_claim, updated_at: '2017-07-26 23:59:59 UTC')
      end

      let(:time) { Time.zone.now }

      let(:submitted_claims) do
        SavedClaim::VeteranReadinessEmploymentClaim.where(
          updated_at: (time - 24.hours)..(time - 1.second)
        )
      end

      let(:mail) { described_class.build(submitted_claims).deliver_now }

      before do
        subject.instance_variable_set(:@time, time)
      end

      it 'sends the right email' do
        subject
        text = described_class::REPORT_TEXT
        expect(mail.subject).to eq(text)
        body = File.read('spec/fixtures/vre_claim/ch31_submissions_report.html').gsub(/\n/, "\r\n")
        expect(mail.body.encoded).to eq(body)
      end

      it 'emails the the right staging recipients' do
        subject
        expect(FeatureFlipper).to receive(:staging_email?).once.and_return(true)

        expect(mail.to).to eq(
          %w[
            kcrawford@governmentcio.com
          ]
        )
      end

      it 'emails the the right recipients' do
        subject
        expect(FeatureFlipper).to receive(:staging_email?).once.and_return(false)

        expect(mail.to).to eq(
          %w[
            VRC.VBABOS@va.gov
            VRE.VBAPRO@va.gov
            VRE.VBANYN@va.gov
            VRC.VBABUF@va.gov
            VRE.VBAHAR@va.gov
            vre.vbanew@va.gov
            VREBDD.VBAPHI@va.gov
            VRE.VBAPIT@va.gov
            VRE.VBABAL@va.gov
            VRE.VBAROA@va.gov
            VRE.VBAHUN@va.gov
            VRETMP.VBAATG@va.gov
            VRE281900.VBASPT@va.gov
            VRC.VBAWIN@va.gov
            VRC.VBACMS@va.gov
            VREAPPS.VBANAS@va.gov
            VRC.VBANOL@va.gov
            VRE.VBAMGY@va.gov
            VRE.VBAJAC@va.gov
            VRE.VBACLE@va.gov
            VRE.VBAIND@va.gov
            VRE.VBALOU@va.gov
            VAVBACHI.VRE@va.gov
            VRE.VBADET@va.gov
            VREApplications.VBAMIW@va.gov
            VRC.VBASTL@va.gov
            VRE.VBADES@va.gov
            VRE.VBALIN@va.gov
            VRC.VBASPL@va.gov
            VRE.VBADEN@va.gov
            VRC.VBAALB@va.gov
            VRE.VBASLC@va.gov
            VRC.VBAOAK@va.gov
            ROVRC.VBALAN@va.gov
            VRE.VBAPHO@va.gov
            VRE.VBASEA@va.gov
            VRE.VBABOI@va.gov
            VRE.VBAPOR@va.gov
            VREAPPS.VBAWAC@va.gov
            VRE.VBALIT@va.gov
            VREBDD.VBAMUS@va.gov
            VRE.VBAREN@va.gov
            MBVRE.VBASAJ@va.gov
            VRE.VBAMPI@va.gov
            VRE.VBAHOU@va.gov
            VRE.VBAWAS@va.gov
            VRE.VBAMAN@va.gov
            EBENAPPS.VBASDC@va.gov
            VRE.VBATOG@va.gov
            VRE.VBAMAN@va.gov
            VRC.VBAFHM@va.gov
            VRC.VBAFAR@va.gov
            VRC.VBAFAR@va.gov
            VRE.VBADEN@va.gov
            VRE.VBAWIC@va.gov
            VRC.VBAHON@va.gov
            VAVBA/WIM/RO/VR&E@vba.va.gov
            VRE.VBAANC@va.gov
            VRE.VBAPIT@va.gov
            VRE-CMS.VBAVACO@va.gov
            Jason.Wolf@va.gov
          ]
        )
      end
    end
  end
end
