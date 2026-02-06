# frozen_string_literal: true

require_relative '../../../support/helpers/rails_helper'
require_relative '../../../support/helpers/committee_helper'

RSpec.describe 'Mobile::V0::Appeal', type: :request do
  include JsonSchemaMatchers
  include CommitteeHelper

  describe 'GET /v0/appeal/:id' do
    let!(:user) { sis_user }

    context 'with an authorized user' do
      let!(:appeal_response) do
        { 'data' =>
            { 'id' => '3294289',
              'type' => 'appeal',
              'attributes' =>
                { 'appealIds' => [],
                  'active' => true,
                  'alerts' => [],
                  'aod' => false,
                  'aoj' => 'vba',
                  'description' => '',
                  'docket' => {},
                  'events' =>
                    [{ 'date' => '2008-04-24', 'type' => 'claim_decision' },
                     { 'date' => '2008-06-11', 'type' => 'nod' },
                     { 'date' => '2010-09-10', 'type' => 'soc' },
                     { 'date' => '2010-11-08', 'type' => 'form9' },
                     { 'date' => '2014-01-03', 'type' => 'ssoc' },
                     { 'date' => '2014-07-28', 'type' => 'certified' },
                     { 'date' => '2015-04-17', 'type' => 'hearing_held' },
                     { 'date' => '2015-07-24', 'type' => 'bva_decision' },
                     { 'date' => '2015-10-06', 'type' => 'ssoc' },
                     { 'date' => '2016-05-03', 'type' => 'bva_decision' },
                     { 'date' => '2018-01-16', 'type' => 'ssoc' }],
                  'evidence' => [],
                  'incompleteHistory' => false,
                  'issues' =>
                    [{ 'active' => true, 'date' => '2016-05-03', 'description' => 'Increased rating, migraines',
                       'diagnosticCode' => '8100', 'lastAction' => 'remand' },
                     { 'active' => true, 'date' => '2016-05-03',
                       'description' => 'Increased rating, limitation of leg motion',
                       'diagnosticCode' => '5260', 'lastAction' => 'remand' },
                     { 'active' => true, 'date' => '2016-05-03',
                       'description' => '100% rating for individual unemployability',
                       'diagnosticCode' => nil, 'lastAction' => 'remand' },
                     { 'active' => false, 'date' => nil, 'description' => 'Service connection, ankylosis of hip',
                       'diagnosticCode' => '5250', 'lastAction' => nil },
                     { 'active' => true, 'date' => '2015-07-24',
                       'description' => 'Service connection, degenerative spinal arthritis', 'diagnosticCode' => '5242',
                       'lastAction' => 'remand' },
                     { 'active' => false, 'date' => nil, 'description' => 'Service connection, hearing loss',
                       'diagnosticCode' => '6100', 'lastAction' => nil },
                     { 'active' => true, 'date' => '2015-07-24',
                       'description' => 'Service connection, sciatic nerve paralysis',
                       'diagnosticCode' => '8520', 'lastAction' => 'remand' },
                     { 'active' => false, 'date' => nil, 'description' => 'Service connection, arthritis due to trauma',
                       'diagnosticCode' => '5010', 'lastAction' => nil },
                     { 'active' => false, 'date' => '2015-07-24',
                       'description' =>
                         'New and material evidence for service connection, degenerative spinal arthritis',
                       'diagnosticCode' => '5242', 'lastAction' => 'allowed' }],
                  'location' => 'aoj',
                  'programArea' => 'compensation',
                  'status' => { 'details' => {}, 'type' => 'remand_ssoc' },
                  'type' => 'legacyAppeal',
                  'updated' => '2018-01-19T10:20:42-05:00' } } }
      end

      context 'with appeals model used' do
        before { Flipper.enable(:mobile_appeal_model) } # rubocop:disable Project/ForbidFlipperToggleInSpecs
        after { Flipper.disable(:mobile_appeal_model) } # rubocop:disable Project/ForbidFlipperToggleInSpecs

        it 'and a result that matches our schema is successfully returned with the 200 status' do
          VCR.use_cassette('caseflow/appeals') do
            get '/mobile/v0/appeal/3294289', headers: sis_headers
            assert_schema_conform(200)
            expect(response.parsed_body).to eq(appeal_response)
          end
        end

        it 'and attempting to access a nonexistent appeal returns a 404 with an error' do
          VCR.use_cassette('caseflow/appeals') do
            get '/mobile/v0/appeal/1234567', headers: sis_headers
            assert_schema_conform(404)
          end
        end

        it 'replaces blank or nil issue descriptions with an appeal type message' do
          # Mock the appeal data to include blank descriptions
          mock_appeal_data = {
            'data' => {
              'id' => '3294289',
              'type' => 'higherLevelReview',
              'attributes' => {
                'appealIds' => [],
                'active' => true,
                'alerts' => [],
                'aod' => false,
                'aoj' => 'vba',
                'description' => '',
                'docket' => {},
                'events' => [],
                'evidence' => [],
                'incompleteHistory' => false,
                'issues' => [
                  { 'active' => true, 'date' => '2016-05-03', 'description' => nil, 'diagnosticCode' => '8100',
                    'lastAction' => 'remand' },
                  { 'active' => true, 'date' => '2016-05-03', 'description' => '', 'diagnosticCode' => '5260',
                    'lastAction' => 'remand' },
                  { 'active' => true, 'date' => '2016-05-03', 'description' => 'Service connection, hearing loss',
                    'diagnosticCode' => '5242', 'lastAction' => 'remand' }
                ],
                'location' => 'aoj',
                'programArea' => 'compensation',
                'status' => { 'details' => {}, 'type' => 'remand_ssoc' },
                'type' => 'legacyAppeal',
                'updated' => '2018-01-19T10:20:42-05:00'
              }
            }
          }

          allow_any_instance_of(Mobile::V0::Claims::Proxy).to receive(:get_appeal).and_return(
            OpenStruct.new(mock_appeal_data['data']['attributes'].merge(
                             id: mock_appeal_data['data']['id'],
                             type: mock_appeal_data['data']['type']
                           ))
          )

          get '/mobile/v0/appeal/3294289', headers: sis_headers

          expect(response).to have_http_status(:ok)
          parsed_response = response.parsed_body
          issues = parsed_response.dig('data', 'attributes', 'issues')

          expect(issues[0]['description']).to eq("We're unable to show this issue on your Higher-Level Review")
          expect(issues[1]['description']).to eq("We're unable to show this issue on your Higher-Level Review")
          expect(issues[2]['description']).to eq('Service connection, hearing loss')
        end
      end

      context 'with appeals model NOT used' do
        before { Flipper.disable(:mobile_appeal_model) } # rubocop:disable Project/ForbidFlipperToggleInSpecs

        it 'and a result that matches our schema is successfully returned with the 200 status' do
          VCR.use_cassette('caseflow/appeals') do
            get '/mobile/v0/appeal/3294289', headers: sis_headers
            assert_schema_conform(200)
            appeal_response['data']['attributes']['docket'] = nil
            expect(response.parsed_body).to eq(appeal_response)
          end
        end

        it 'and attempting to access a nonexistant appeal returns a 404 wtih an error' do
          VCR.use_cassette('caseflow/appeals') do
            get '/mobile/v0/appeal/1234567', headers: sis_headers
            assert_schema_conform(404)
          end
        end
      end
    end

    context 'with an unauthorized user' do
      let!(:user) { sis_user(loa: { current: LOA::TWO, highest: LOA::TWO }) }

      it 'returns 403 status' do
        VCR.use_cassette('caseflow/appeals') do
          get '/mobile/v0/appeal/3294289', headers: sis_headers
          assert_schema_conform(403)
        end
      end
    end
  end
end
