# frozen_string_literal: true

require 'rails_helper'
require 'evss/disability_compensation_form/form0781'

describe EVSS::DisabilityCompensationForm::Form0781 do
  let(:subject_v1) { described_class.new(user, form_content_v1) }
  let(:subject_v2) { described_class.new(user, form_content_v2) }

  let(:form_content_v1) do
    JSON.parse(File.read('spec/support/disability_compensation_form/submit_all_claim/0781.json'))
  end
  let(:form_content_v2) do
    JSON.parse(File.read('spec/support/disability_compensation_form/submit_all_claim/0781v2.json'))
  end
  let(:user) { build(:disabilities_compensation_user) }

  before do
    User.create(user)
  end

  describe '#translate' do
    context 'when using form v1' do
      context 'when 0781 data is present in the 526 form' do
        let(:expected_output) { JSON.parse(File.read('spec/support/disability_compensation_form/form_0781.json')) }

        it 'returns correctly formatted json to send to async job' do
          expect(subject_v1.translate).to eq expected_output
        end
      end

      context 'when 0781 is not present in the 526 form' do
        let(:form_content_v1) { { 'form526' => {} } }

        it 'returns a nil value' do
          expect(subject_v1.translate).to be_nil
        end
      end
    end

    context 'when using form v2' do
      context 'when 0781 data is present in the 526 form' do
        let(:expected_output) { JSON.parse(File.read('spec/support/disability_compensation_form/form_0781v2.json')) }

        it 'returns correctly formatted json to send to async job' do
          expect(subject_v2.translate).to eq expected_output
        end
      end

      context 'when 0781 is not present in the 526 form' do
        let(:form_content_v2) { { 'form526' => {} } }

        it 'returns a nil value' do
          expect(subject_v2.translate).to be_nil
        end
      end
    end
  end

  describe '#create_form' do
    context 'when the form exists and has incidents' do
      let(:incidents) { 'this is a test' }

      it 'creates the form correctly' do
        expect(subject_v1.send(:create_form, incidents)).to eq(
          'additionalIncidentText' => nil,
          'email' => 'test@email.com',
          'incidents' => 'this is a test',
          'otherInformation' => nil,
          'remarks' => nil,
          'vaFileNumber' => '796068949',
          'veteranDateOfBirth' => '1809-02-12',
          'veteranFullName' => {
            'first' => 'Beyonce', 'middle' => nil, 'last' => 'Knowles'
          },
          'veteranPhone' => '2024561111',
          'veteranSecondaryPhone' => '',
          'veteranServiceNumber' => '',
          'veteranSocialSecurityNumber' => '796068949'
        )
      end
    end
  end

  describe '#split_incidents' do
    context 'when there are incidents' do
      let(:incidents) do
        [
          {
            'personalAssault' => true,
            'test' => 'foo1'
          },
          {
            'personalAssault' => true,
            'test' => 'foo2'
          },
          {
            'personalAssault' => false,
            'test' => 'bar1'
          },
          {
            'personalAssault' => false,
            'test' => 'bar2'
          }
        ]
      end

      it 'splits the incidents on personalAssualt' do
        expect(subject_v1.send(:split_incidents, incidents)).to eq [
          [
            { 'personalAssault' => true, 'test' => 'foo1' },
            { 'personalAssault' => true, 'test' => 'foo2' }
          ],
          [
            { 'personalAssault' => false, 'test' => 'bar1' },
            { 'personalAssault' => false, 'test' => 'bar2' }
          ]
        ]
      end
    end

    context 'when there are no incidents' do
      let(:incidents) { [] }

      it 'returns a nil value' do
        expect(subject_v1.send(:split_incidents, incidents)).to be_nil
      end
    end
  end

  describe '#join_location' do
    context 'when given a full address' do
      let(:location) do
        {
          'city' => 'Portland',
          'state' => 'OR',
          'country' => 'USA',
          'additionalDetails' => 'Apt. 1'
        }
      end

      it 'joins it into one string' do
        expect(subject_v1.send(:join_location, location)).to eq 'Portland, OR, USA, Apt. 1'
      end
    end

    context 'when given a partial address' do
      let(:location) do
        {
          'city' => 'Portland',
          'state' => '',
          'country' => 'USA'
        }
      end

      it 'joins it into one string' do
        expect(subject_v1.send(:join_location, location)).to eq 'Portland, USA'
      end
    end

    context 'when given no address' do
      let(:location) { {} }

      it 'joins it into one string' do
        expect(subject_v1.send(:join_location, location)).to eq ''
      end
    end
  end

  describe '#full_name' do
    context 'when using form v1' do
      context 'when the user has a full name' do
        it 'returns a hash of their name' do
          expect(subject_v1.send(:full_name)).to eq(
            'first' => 'Beyonce',
            'middle' => nil,
            'last' => 'Knowles'
          )
        end
      end
    end

    context 'when using form v2' do
      context 'when the user has a full name' do
        it 'returns a hash of their name' do
          expect(subject_v2.send(:full_name)).to eq(
            'first' => 'Beyonce',
            'middle' => nil,
            'last' => 'Knowles'
          )
        end
      end
    end
  end

  describe 'when using form v2' do
    describe '#aggregate_behaviors' do
      context 'when all behavior categories have values' do
        it 'merges all behaviors and removes falsy values' do
          expect(subject_v2.send(:aggregate_behaviors)).to eq(
            {
              'reassignment' => true,
              'performance' => true,
              'consultations' => true,
              'episodes' => true,
              'selfMedication' => true,
              'substances' => true,
              'appetite' => true,
              'screenings' => true,
              'relationships' => true,
              'unlisted' => true
            }
          )
        end
      end
    end

    describe '#aggregate_supporting_evidence' do
      context 'when supportingEvidenceUnlisted is present' do
        it 'adds other and otherDetails' do
          expect(subject_v2.send(:aggregate_supporting_evidence)).to eq(
            {
              'police' => true,
              'medical' => true,
              'counseling' => true,
              'family' => true,
              'service' => true,
              'personal' => true,
              'other' => true,
              'otherDetails' => 'Lorem ipsum dolor sit amet.'
            }
          )
        end
      end
    end

    describe '#aggregate_treatment_providers' do
      context 'when treatment providers have values' do
        it 'merges treatment providers and removes falsy values' do
          expect(subject_v2.send(:aggregate_treatment_providers)).to eq(
            {
              'medicalCenter' => true,
              'dod' => true,
              'nonVa' => true
            }
          )
        end
      end
    end

    describe '#sanitize_text' do
      it 'replaces newlines and carriage returns with spaces' do
        expect(subject_v2.send(:sanitize_text, "line1\nline2\rline3")).to eq('line1 line2 line3')
      end

      it 'leaves strings without line breaks untouched' do
        expect(subject_v2.send(:sanitize_text, 'no line breaks')).to eq('no line breaks')
      end
    end

    describe '#sanitize_hash_values' do
      let(:input_hash) do
        {
          'reassignment' => "\nReassigned\r\nto\ndifferent\n\ndepartment\nfor\nconduct"
        }
      end

      it 'sanitizes all string values in a hash' do
        expect(subject_v2.send(:sanitize_hash_values, input_hash)).to eq(
          {
            'reassignment' => ' Reassigned  to different  department for conduct'
          }
        )
      end
    end

    describe '#sanitize_details' do
      let(:events) do
        [
          {
            'details' => "Witnessed\nan incident\rat the barracks.\n\n\nFiled a report.",
            'location' => 'Fort Bragg'
          },
          {
            'location' => 'No specific details provided'
          }
        ]
      end

      it 'sanitizes the details key in each event' do
        sanitized = subject_v2.send(:sanitize_details, events)

        expect(sanitized[0]['details']).to eq('Witnessed an incident at the barracks.   Filed a report.')
        expect(sanitized[0]['location']).to eq('Fort Bragg')

        expect(sanitized[1]['location']).to eq('No specific details provided')
        expect(sanitized[1]).not_to have_key('details')
      end
    end
  end
end
