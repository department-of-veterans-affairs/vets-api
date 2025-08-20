# frozen_string_literal: true

require './modules/decision_reviews/spec/dr_spec_helper'
require './modules/decision_reviews/spec/support/vcr_helper'

RSpec.describe DecisionReviews::V1::SupplementalClaimsController, type: :controller do
  routes { DecisionReviews::Engine.routes }

  let(:user) { build(:user, :loa3) }

  before do
    sign_in_as(user)
  end

  describe '#normalize_evidence_retrieval_for_lighthouse_schema' do
    subject(:normalized_data) { controller.send(:normalize_evidence_retrieval_for_lighthouse_schema, req_body_obj) }

    context 'when retrieveFrom is an array with no duplicates' do
      let(:req_body_obj) do
        {
          'data' => {
            'attributes' => {
              'evidenceSubmission' => {
                'evidenceType' => ['retrieval'],
                'retrieveFrom' => [
                  {
                    'attributes' => {
                      'locationAndName' => 'VA Medical Center - Boston',
                      'evidenceDates' => [
                        { 'startDate' => '2005-01', 'endDate' => '2005-01' }
                      ]
                    }
                  },
                  {
                    'attributes' => {
                      'locationAndName' => 'VA Medical Center - Philadelphia',
                      'evidenceDates' => [
                        { 'startDate' => '2004-01', 'endDate' => '2004-01' }
                      ]
                    }
                  }
                ]
              }
            }
          }
        }
      end

      it 'returns the original array unchanged' do
        expect(normalized_data).to eq(req_body_obj)
      end
    end

    context 'when retrieveFrom has duplicate locations' do
      let(:req_body_obj) do
        {
          'data' => {
            'attributes' => {
              'evidenceSubmission' => {
                'evidenceType' => ['retrieval'],
                'retrieveFrom' => [
                  {
                    'attributes' => {
                      'locationAndName' => 'VA Medical Center - Boston',
                      'evidenceDates' => [
                        { 'startDate' => '2005-01', 'endDate' => '2005-01' }
                      ]
                    }
                  },
                  {
                    'attributes' => {
                      'locationAndName' => 'VA Medical Center - Boston',
                      'evidenceDates' => [
                        { 'startDate' => '2004-01', 'endDate' => '2004-01' }
                      ]
                    }
                  }
                ]
              }
            }
          }
        }
      end

      let(:expected_result) do
        {
          'data' => {
            'attributes' => {
              'evidenceSubmission' => {
                'evidenceType' => ['retrieval'],
                'retrieveFrom' => [
                  {
                    'attributes' => {
                      'locationAndName' => 'VA Medical Center - Boston',
                      'evidenceDates' => [
                        { 'startDate' => '2004-01', 'endDate' => '2004-01' },
                        { 'startDate' => '2005-01', 'endDate' => '2005-01' }
                      ]
                    }
                  }
                ]
              }
            }
          }
        }
      end

      it 'merges entries with the same location' do
        expect(normalized_data).to eq(expected_result)
      end
    end
  end

  describe '#handle_area_code_for_schema_validation' do
    subject(:formatted_data) { controller.send(:handle_area_code_for_schema_validation, req_body_obj) }

    context 'when area_code is present and valid with 3 characters (domestic number)' do
      let(:req_body_obj) do
        {
          'data' => {
            'attributes' => {
              'veteran' => {
                'phone' => {
                  'areaCode' => '123',
                  'phoneNumber' => '1234567',
                  'countryCode' => '1'
                }
              }
            }
          }
        }
      end

      it 'returns the original object unchanged' do
        expected_result = req_body_obj
        expect(formatted_data).to eq(expected_result)
      end
    end

    context 'when area_code is present and valid with 2 characters (international number)' do
      let(:req_body_obj) do
        {
          'data' => {
            'attributes' => {
              'veteran' => {
                'phone' => {
                  'areaCode' => '10',
                  'phoneNumber' => '49808232',
                  'countryCode' => '100'
                }
              }
            }
          }
        }
      end

      it 'returns the original object unchanged' do
        expected_result = req_body_obj
        expect(formatted_data).to eq(expected_result)
      end
    end

    context 'when area_code is present and empty' do
      let(:req_body_obj) do
        {
          'data' => {
            'attributes' => {
              'veteran' => {
                'phone' => {
                  'areaCode' => '',
                  'phoneNumber' => '12343432567',
                  'countryCode' => '44'
                }
              }
            }
          }
        }
      end

      let(:expected_result) do
        {
          'data' => {
            'attributes' => {
              'veteran' => {
                'phone' => {
                  'phoneNumber' => '12343432567',
                  'countryCode' => '44'
                }
              }
            }
          }
        }
      end

      it 'returns the object without an areaCode' do
        expect(formatted_data).to eq(expected_result)
      end
    end

    context 'when area_code is present and nil' do
      let(:req_body_obj) do
        {
          'data' => {
            'attributes' => {
              'veteran' => {
                'phone' => {
                  'areaCode' => nil,
                  'phoneNumber' => '12343432567',
                  'countryCode' => '44'
                }
              }
            }
          }
        }
      end

      let(:expected_result) do
        {
          'data' => {
            'attributes' => {
              'veteran' => {
                'phone' => {
                  'phoneNumber' => '12343432567',
                  'countryCode' => '44'
                }
              }
            }
          }
        }
      end

      it 'returns the object without an areaCode' do
        expect(formatted_data).to eq(expected_result)
      end
    end
  end

  describe '#merge_evidence_entries' do
    subject(:merged_entry) { controller.send(:merge_evidence_entries, entries) }

    context 'when entries have different evidence dates' do
      let(:entries) do
        [
          {
            'attributes' => {
              'locationAndName' => 'VA Medical Center - Boston',
              'evidenceDates' => [
                { 'startDate' => '2005-01', 'endDate' => '2005-01' }
              ]
            }
          },
          {
            'attributes' => {
              'locationAndName' => 'VA Medical Center - Boston',
              'evidenceDates' => [
                { 'startDate' => '2004-01', 'endDate' => '2004-01' }
              ]
            }
          }
        ]
      end

      let(:expected_result) do
        {
          'attributes' => {
            'locationAndName' => 'VA Medical Center - Boston',
            'evidenceDates' => [
              { 'startDate' => '2004-01', 'endDate' => '2004-01' },
              { 'startDate' => '2005-01', 'endDate' => '2005-01' }
            ]
          }
        }
      end

      it 'combines all evidence dates in chronological order' do
        expect(merged_entry).to eq(expected_result)
      end
    end

    context 'when entries have duplicate evidence dates' do
      let(:entries) do
        [
          {
            'attributes' => {
              'locationAndName' => 'VA Medical Center - Boston',
              'evidenceDates' => [
                { 'startDate' => '2005-01', 'endDate' => '2005-01' }
              ]
            }
          },
          {
            'attributes' => {
              'locationAndName' => 'VA Medical Center - Boston',
              'evidenceDates' => [
                { 'startDate' => '2005-01', 'endDate' => '2005-01' }
              ]
            }
          }
        ]
      end

      let(:expected_result) do
        {
          'attributes' => {
            'locationAndName' => 'VA Medical Center - Boston',
            'evidenceDates' => [
              { 'startDate' => '2005-01', 'endDate' => '2005-01' }
            ]
          }
        }
      end

      it 'removes duplicate evidence dates' do
        expect(merged_entry).to eq(expected_result)
      end
    end

    context 'when there are more than 4 evidence dates from multiple entries' do
      let(:entries) do
        [
          {
            'attributes' => {
              'locationAndName' => 'VA Medical Center - Boston',
              'evidenceDates' => [
                { 'startDate' => '2005-01', 'endDate' => '2005-01' }
              ]
            }
          },
          {
            'attributes' => {
              'locationAndName' => 'VA Medical Center - Boston',
              'evidenceDates' => [
                { 'startDate' => '2004-01', 'endDate' => '2004-01' }
              ]
            }
          },
          {
            'attributes' => {
              'locationAndName' => 'VA Medical Center - Boston',
              'evidenceDates' => [
                { 'startDate' => '2003-01', 'endDate' => '2003-01' }
              ]
            }
          },
          {
            'attributes' => {
              'locationAndName' => 'VA Medical Center - Boston',
              'evidenceDates' => [
                { 'startDate' => '2001-01', 'endDate' => '2001-01' }
              ]
            }
          },
          {
            'attributes' => {
              'locationAndName' => 'VA Medical Center - Boston',
              'evidenceDates' => [
                { 'startDate' => '2024-01', 'endDate' => '2024-01' }
              ]
            }
          }
        ]
      end

      let(:expected_result) do
        {
          'attributes' => {
            'locationAndName' => 'VA Medical Center - Boston',
            'evidenceDates' => [
              { 'startDate' => '2001-01', 'endDate' => '2001-01' },
              { 'startDate' => '2003-01', 'endDate' => '2003-01' },
              { 'startDate' => '2004-01', 'endDate' => '2004-01' },
              { 'startDate' => '2005-01', 'endDate' => '2005-01' }
            ]
          }
        }
      end

      it 'limits to the first 4 evidence dates' do
        expect(merged_entry).to eq(expected_result)
        expect(merged_entry['attributes']['evidenceDates'].length).to eq(4)
      end
    end

    context 'when entries have nil evidenceDates' do
      let(:entries) do
        [
          {
            'attributes' => {
              'locationAndName' => 'VA Medical Center - Boston',
              'evidenceDates' => nil
            }
          },
          {
            'attributes' => {
              'locationAndName' => 'VA Medical Center - Boston',
              'evidenceDates' => [
                { 'startDate' => '2004-01', 'endDate' => '2004-01' }
              ]
            }
          }
        ]
      end

      let(:expected_result) do
        {
          'attributes' => {
            'locationAndName' => 'VA Medical Center - Boston',
            'evidenceDates' => [
              { 'startDate' => '2004-01', 'endDate' => '2004-01' }
            ]
          }
        }
      end

      it 'handles nil evidence dates gracefully' do
        expect(merged_entry).to eq(expected_result)
      end
    end
  end
end
