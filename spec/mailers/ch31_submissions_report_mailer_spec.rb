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

      let(:submitted_claims) do
        [vre_claim_1, vre_claim_2]
      end

      let(:mail) { described_class.build(submitted_claims).deliver_now }

      it 'sends the right email' do
        subject
        text = described_class::REPORT_TEXT
        expect(mail.subject).to eq(text)
        expect(mail.body.encoded).to include(
          'Count',
          'Regional Office',
          'PID',
          'Date Application Received',
          'Type of Form',
          'e-VA',
          'Tele-counseling',
          'Total'
        )
      end

      it 'emails the the right recipients' do
        subject
        expect(mail.to).to include(
          *%w[
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
          ]
        )
      end
    end
  end
end
