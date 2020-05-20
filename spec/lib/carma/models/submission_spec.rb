# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CARMA::Models::Submission, type: :model do
  describe '#carma_case_id' do
    it 'is accessible' do
      value = 'aB935000000A9GoCAK'

      subject.carma_case_id = value
      expect(subject.carma_case_id).to eq(value)
    end
  end

  describe '#submitted_at' do
    it 'is accessible' do
      value = DateTime.now.iso8601

      subject.submitted_at = value
      expect(subject.submitted_at).to eq(value)
    end
  end

  describe '#submitted?' do
    it 'returns true if :carma_case_id is set' do
      subject.carma_case_id = 'aB935000000A9GoCAK'
      expect(subject.submitted?).to eq(true)
    end

    it 'returns true if :submitted_at is set' do
      subject.submitted_at = DateTime.now.iso8601
      expect(subject.submitted?).to eq(true)
    end

    it 'returns false if :carma_case_id and :submitted_at are falsy' do
      expect(subject.submitted?).to eq(false)
    end
  end

  describe '#data' do
    it 'is accessible' do
      value = { 'my' => 'data' }

      subject.data = value
      expect(subject.data).to eq(value)
    end
  end

  describe '#metadata' do
    it 'is accessible' do
      subject.metadata = {
        claim_id: 123,
        veteran: {
          icn: 'VET1234',
          is_veteran: true
        },
        primary_caregiver: {
          icn: 'PC1234'
        },
        secondary_caregiver_one: {
          icn: 'SCO1234'
        },
        secondary_caregiver_two: {
          icn: 'SCT1234'
        }
      }

      # metadata
      expect(subject.metadata).to be_instance_of(described_class::Metadata)
      expect(subject.metadata.claim_id).to eq(123)
      # metadata.veteran
      expect(subject.metadata.veteran).to be_instance_of(described_class::Metadata::Veteran)
      expect(subject.metadata.veteran.icn).to eq('VET1234')
      expect(subject.metadata.veteran.is_veteran).to eq(true)
      # metadata.primary_caregiver
      expect(subject.metadata.primary_caregiver).to be_instance_of(described_class::Metadata::Caregiver)
      expect(subject.metadata.primary_caregiver.icn).to eq('PC1234')
      # metadata.secondary_caregiver_one
      expect(subject.metadata.secondary_caregiver_one).to be_instance_of(described_class::Metadata::Caregiver)
      expect(subject.metadata.secondary_caregiver_one.icn).to eq('SCO1234')
      # metadata.secondary_caregiver_two
      expect(subject.metadata.secondary_caregiver_two).to be_instance_of(described_class::Metadata::Caregiver)
      expect(subject.metadata.secondary_caregiver_two.icn).to eq('SCT1234')
    end
  end

  describe '::new' do
    it 'initializes with defaults' do
      expect(subject.carma_case_id).to eq(nil)
      expect(subject.submitted_at).to eq(nil)
      expect(subject.data).to eq(nil)
      # metadata
      expect(subject.metadata).to be_instance_of(described_class::Metadata)
      expect(subject.metadata.claim_id).to eq(nil)
      # metadata.veteran
      expect(subject.metadata.veteran).to be_instance_of(described_class::Metadata::Veteran)
      expect(subject.metadata.veteran.icn).to eq(nil)
      expect(subject.metadata.veteran.is_veteran).to eq(nil)
      # metadata.primary_caregiver
      expect(subject.metadata.primary_caregiver).to be_instance_of(described_class::Metadata::Caregiver)
      expect(subject.metadata.primary_caregiver.icn).to eq(nil)
      # metadata.secondary_caregiver_one
      expect(subject.metadata.secondary_caregiver_one).to eq(nil)
      # metadata.secondary_caregiver_two
      expect(subject.metadata.secondary_caregiver_two).to eq(nil)
    end

    it 'accepts :carma_case_id, :submitted_at, :data, and :metadata' do
      expected = {
        carma_case_id: 'aB935000000A9GoCAK',
        submitted_at: DateTime.now.iso8601,
        data: {
          'my' => 'data'
        }
      }

      subject = described_class.new(
        carma_case_id: expected[:carma_case_id],
        submitted_at: expected[:submitted_at],
        data: expected[:data],
        metadata: {
          claim_id: 123,
          veteran: {
            icn: 'VET1234',
            is_veteran: true
          },
          primary_caregiver: {
            icn: 'PC1234'
          },
          secondary_caregiver_one: {
            icn: 'SCO1234'
          },
          secondary_caregiver_two: {
            icn: 'SCT1234'
          }
        }
      )

      expect(subject.carma_case_id).to eq(expected[:carma_case_id])
      expect(subject.submitted_at).to eq(expected[:submitted_at])
      expect(subject.data).to eq(expected[:data])
      # metadata
      expect(subject.metadata).to be_instance_of(described_class::Metadata)
      expect(subject.metadata.claim_id).to eq(123)
      # metadata.veteran
      expect(subject.metadata.veteran).to be_instance_of(described_class::Metadata::Veteran)
      expect(subject.metadata.veteran.icn).to eq('VET1234')
      expect(subject.metadata.veteran.is_veteran).to eq(true)
      # metadata.primary_caregiver
      expect(subject.metadata.primary_caregiver).to be_instance_of(described_class::Metadata::Caregiver)
      expect(subject.metadata.primary_caregiver.icn).to eq('PC1234')
      # metadata.secondary_caregiver_one
      expect(subject.metadata.secondary_caregiver_one).to be_instance_of(described_class::Metadata::Caregiver)
      expect(subject.metadata.secondary_caregiver_one.icn).to eq('SCO1234')
      # metadata.secondary_caregiver_two
      expect(subject.metadata.secondary_caregiver_two).to be_instance_of(described_class::Metadata::Caregiver)
      expect(subject.metadata.secondary_caregiver_two.icn).to eq('SCT1234')
    end
  end

  describe '::from_claim' do
    it 'transforms a CaregiversAssistanceClaim to a new CARMA::Model::Submission' do
      claim = build(:caregivers_assistance_claim)

      submission = described_class.from_claim(claim)

      expect(submission).to be_instance_of(described_class)
      expect(submission.data).to eq(claim.parsed_form)
      expect(submission.carma_case_id).to eq(nil)
      expect(submission.submitted_at).to eq(nil)

      expect(submission.metadata).to be_instance_of(described_class::Metadata)
      expect(submission.metadata.claim_id).to eq(claim.id)
    end

    it 'will override :claim_id when passed in metadata and use claim.id instead' do
      claim = build(:caregivers_assistance_claim)

      submission = described_class.from_claim(claim, claim_id: 99)

      expect(submission).to be_instance_of(described_class)
      expect(submission.data).to eq(claim.parsed_form)
      expect(submission.carma_case_id).to eq(nil)
      expect(submission.submitted_at).to eq(nil)

      expect(submission.metadata).to be_instance_of(described_class::Metadata)
      expect(submission.metadata.claim_id).to eq(claim.id)
    end
  end

  describe '::request_payload_keys' do
    it 'inherits fron Base' do
      expect(described_class.ancestors).to include(CARMA::Models::Base)
    end

    it 'sets request_payload_keys' do
      expect(described_class.request_payload_keys).to eq(%i[data metadata])
    end
  end

  describe '#to_request_payload' do
    it 'can receive :to_request_payload' do
      subject = described_class.new(
        data: {
          'my' => 'data'
        },
        metadata: {
          claim_id: 123,
          veteran: {
            icn: 'VET1234',
            is_veteran: true
          },
          primary_caregiver: {
            icn: 'PC1234'
          },
          secondary_caregiver_one: {
            icn: 'SCO1234'
          },
          secondary_caregiver_two: {
            icn: 'SCT1234'
          }
        }
      )

      expect(subject.to_request_payload).to eq(
        {
          'data' => {
            'my' => 'data'
          },
          'metadata' => {
            'claimId' => 123,
            'veteran' => {
              'icn' => 'VET1234',
              'isVeteran' => true
            },
            'primaryCaregiver' => {
              'icn' => 'PC1234'
            },
            'secondaryCaregiverOne' => {
              'icn' => 'SCO1234'
            },
            'secondaryCaregiverTwo' => {
              'icn' => 'SCT1234'
            }
          }
        }
      )
    end

    context 'when metadata.veteran.is_veteran is false' do
      it 'will set metadata.veteran.icn to nil' do
        subject = described_class.new(
          data: {
            'my' => 'data'
          },
          metadata: {
            claim_id: 123,
            veteran: {
              icn: 'VET1234',
              is_veteran: false
            },
            primary_caregiver: {
              icn: 'PC1234'
            },
            secondary_caregiver_one: {
              icn: 'SCO1234'
            },
            secondary_caregiver_two: {
              icn: 'SCT1234'
            }
          }
        )

        expect(subject.to_request_payload).to eq(
          {
            'data' => {
              'my' => 'data'
            },
            'metadata' => {
              'claimId' => 123,
              'veteran' => {
                'icn' => nil,
                'isVeteran' => false
              },
              'primaryCaregiver' => {
                'icn' => 'PC1234'
              },
              'secondaryCaregiverOne' => {
                'icn' => 'SCO1234'
              },
              'secondaryCaregiverTwo' => {
                'icn' => 'SCT1234'
              }
            }
          }
        )
      end
    end
  end

  describe '#submit!' do
    let(:submission) do
      CARMA::Models::Submission.from_claim(
        build(:caregivers_assistance_claim),
        {
          veteran: {
            icn: 'VET1234',
            is_veteran: true
          },
          primary_caregiver: {
            icn: 'PC1234'
          },
          secondary_caregiver_one: {
            icn: 'SCO1234'
          },
          secondary_caregiver_two: {
            icn: 'SCT1234'
          }
        }
      )
    end

    context 'when already submitted' do
      it 'raises an exception' do
        submission.submitted_at = DateTime.now.iso8601
        submission.carma_case_id = 'aB935000000A9GoCAK'

        expect { submission.submit! }.to raise_error('This submission has already been submitted to CARMA')
      end
    end

    context 'when Flipper enabled' do
      it 'submits to CARMA, and updates :carma_case_id and :submitted_at' do
        expected_carma_body = {
          'data' => {
            'carmacase' => {
              'id' => 'aB935000000F3VnCAK',
              'createdAt' => '2020-03-09T10:48:59Z'
            }
          }
        }

        expect(Flipper).to receive(:enabled?).with(:stub_carma_responses).and_return(false)
        expect_any_instance_of(CARMA::Client::Client).not_to receive(:create_submission_stub)

        expect(submission.carma_case_id).to eq(nil)
        expect(submission.submitted_at).to eq(nil)
        expect(submission.submitted?).to eq(false)

        VCR.use_cassette 'carma/submissions/create/201' do
          submission.submit!
        end

        expect(submission.carma_case_id).to eq(expected_carma_body['data']['carmacase']['id'])
        expect(submission.submitted_at).to eq(expected_carma_body['data']['carmacase']['createdAt'])
        expect(submission.submitted?).to eq(true)
      end
    end

    context 'when Flipper disabled' do
      it 'returns a hardcoded CARMA response, and updates :carma_case_id and :submitted_at' do
        expected_carma_body = {
          'data' => {
            'carmacase' => {
              'id' => 'aB935000000F3VnCAK',
              'createdAt' => '2020-03-09T10:48:59Z'
            }
          }
        }

        expect(Flipper).to receive(:enabled?).with(:stub_carma_responses).and_return(true)
        expect_any_instance_of(CARMA::Client::Client).not_to receive(:create_submission)

        expect_any_instance_of(CARMA::Client::Client).to receive(
          :create_submission_stub
        ).and_return(
          expected_carma_body
        )

        expect(submission.carma_case_id).to eq(nil)
        expect(submission.submitted_at).to eq(nil)
        expect(submission.submitted?).to eq(false)

        submission.submit!

        expect(submission.carma_case_id).to eq(expected_carma_body['data']['carmacase']['id'])
        expect(submission.submitted_at).to eq(expected_carma_body['data']['carmacase']['createdAt'])
        expect(submission.submitted?).to eq(true)
      end
    end
  end
end
