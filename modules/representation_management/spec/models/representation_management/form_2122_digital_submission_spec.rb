# frozen_string_literal: true

require 'rails_helper'

RSpec.describe RepresentationManagement::Form2122DigitalSubmission, type: :model do
  describe '#normalized_limitations_of_consent' do
    context 'when record_consent is true' do
      context 'when consent_limits is empty' do
        it 'returns an empty array' do
          form = described_class.new(record_consent: true, consent_limits: [])

          expect(form.normalized_limitations_of_consent).to eq([])
        end
      end

      context 'when consent_limits is present' do
        context 'less than all limitations' do
          it 'returns the values from the allowed limitations list not in consent_limits' do
            form = described_class.new(record_consent: true, consent_limits: %w[DRUG_ABUSE HIV])

            expect(form.normalized_limitations_of_consent).to match_array(%w[ALCOHOLISM SICKLE_CELL])
          end
        end

        context 'all limitations' do
          it 'returns the an empty array' do
            allowed_list = RepresentationManagement::Form2122Base::LIMITATIONS_OF_CONSENT
            form = described_class.new(record_consent: true, consent_limits: allowed_list)

            expect(form.normalized_limitations_of_consent).to eq([])
          end
        end
      end
    end

    context 'when record_consent is false' do
      it 'returns the full allowed limitations list' do
        form = described_class.new(record_consent: false)

        allowed_list = RepresentationManagement::Form2122Base::LIMITATIONS_OF_CONSENT

        expect(form.normalized_limitations_of_consent).to match_array(allowed_list)
      end
    end
  end

  describe '#organization' do
    context 'when organization is found in AccreditedOrganization' do
      it 'returns the AccreditedOrganization' do
        accredited_organization = create(:accredited_organization, name: 'Accredited Org Name')
        form = described_class.new(organization_id: accredited_organization.id)

        expect(form.organization).to eq(accredited_organization)
      end
    end

    context 'when organization is found in Veteran::Service::Organization' do
      it 'returns the Veteran::Service::Organization' do
        veteran_org = create(:organization, name: 'Veteran Org Name')
        form = described_class.new(organization_id: veteran_org.poa)

        expect(form.organization).to eq(veteran_org)
      end
    end

    context 'when organization is not found in either' do
      it 'returns nil' do
        form = described_class.new(organization_id: 'Nonexistent Org')

        expect(form.organization).to be_nil
      end
    end
  end

  describe 'validations' do
    subject { described_class.new(user:, dependent:, organization_id:) }

    let(:user) { create(:user, :loa3) }
    let!(:user_verification) { create(:idme_user_verification, idme_uuid: user.idme_uuid) }
    let(:dependent) { false }
    let(:organization_id) { 'ABC' }

    it { expect(subject).to validate_presence_of(:organization_id) }

    context 'organization_exists?' do
      context 'when the organization does not exist' do
        it 'adds the organization not found error to the form' do
          subject.valid?

          error_message = RepresentationManagement::Form2122DigitalSubmission::NOT_FOUND

          expect(subject.errors[:organization]).to include(error_message)
        end
      end

      context 'when the organization exists' do
        let(:organization) { create(:organization, name: 'Veteran Org Name') }
        let(:organization_id) { organization.poa }

        it 'does not add the organization not found error to the form' do
          subject.valid?

          error_message = RepresentationManagement::Form2122DigitalSubmission::NOT_FOUND

          expect(subject.errors[:organization]).not_to include(error_message)
        end
      end
    end

    context 'organization_accepts_digital_poa_requests?' do
      let(:organization) { create(:organization, name: 'Veteran Org Name', can_accept_digital_poa_requests:) }
      let(:organization_id) { organization.poa }

      context 'when the organization does not accept digital requests' do
        let(:can_accept_digital_poa_requests) { false }

        it 'adds the organization does not accept digital requests error to the form' do
          subject.valid?

          error_message = RepresentationManagement::Form2122DigitalSubmission::DOES_NOT_ACCEPT_DIGITAL_REQUESTS

          expect(subject.errors[:organization]).to include(error_message)
        end
      end

      context 'when the organization accepts digital requests' do
        let(:can_accept_digital_poa_requests) { true }

        it 'does not add the organization does not accept digital requests error to the form' do
          subject.valid?

          error_message = RepresentationManagement::Form2122DigitalSubmission::DOES_NOT_ACCEPT_DIGITAL_REQUESTS

          expect(subject.errors[:organization]).not_to include(error_message)
        end
      end
    end

    context 'user_is_submitting_as_veteran?' do
      context 'when the user is not submitting as the Veteran' do
        let(:dependent) { true }

        it 'adds the dependent submitter error to the form' do
          subject.valid?

          error_message = RepresentationManagement::Form2122DigitalSubmission::DEPENDENT_SUBMITTER

          expect(subject.errors[:user]).to include(error_message)
        end
      end

      context 'when the user is submitting as the Veteran' do
        it 'does not add the dependent submitter error to the form' do
          subject.valid?

          error_message = RepresentationManagement::Form2122DigitalSubmission::DEPENDENT_SUBMITTER

          expect(subject.errors[:user]).not_to include(error_message)
        end
      end
    end

    context 'user_has_participant_id?' do
      context 'when the user does not have a participant id' do
        let(:user) { create(:user, participant_id: nil) }

        it 'adds the blank participant id error to the form' do
          subject.valid?

          error_message = RepresentationManagement::Form2122DigitalSubmission::BLANK_PARTICIPANT_ID

          expect(subject.errors[:user]).to include(error_message)
        end
      end

      context 'when the user has a participant id' do
        it 'does not add the blank participant id error to the form' do
          subject.valid?

          error_message = RepresentationManagement::Form2122DigitalSubmission::BLANK_PARTICIPANT_ID

          expect(subject.errors[:user]).not_to include(error_message)
        end
      end
    end

    context 'user_has_icn?' do
      context 'when the user does not have an ICN' do
        let(:user) { create(:user, :loa3, icn: nil) }

        it 'adds the blank ICN error to the form' do
          subject.valid?

          error_message = RepresentationManagement::Form2122DigitalSubmission::BLANK_ICN

          expect(subject.errors[:user]).to include(error_message)
        end
      end

      context 'when the user has a participant id' do
        it 'does not add the blank ICN error to the form' do
          subject.valid?

          error_message = RepresentationManagement::Form2122DigitalSubmission::BLANK_ICN

          expect(subject.errors[:user]).not_to include(error_message)
        end
      end
    end
  end
end
