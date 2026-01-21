# frozen_string_literal: true

require 'rails_helper'

describe Mobile::V0::Adapters::Appeal, :aggregate_failures do
  let(:appeals) do
    [{ 'attributes' =>
                { 'appealIds' => [],
                  'active' => true,
                  'alerts' => [],
                  'aod' => false,
                  'aoj' => 'vba',
                  'description' => '',
                  'docket' => nil,
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
                   [{ 'active' => true, 'date' => '2016-05-03',
                      'description' => 'Increased rating, migraines',
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
                      'description' => 'Service connection, sciatic nerve paralysis', 'diagnosticCode' => '8520',
                      'lastAction' => 'remand' },
                    { 'active' => false, 'date' => nil, 'description' => 'Service connection, arthritis due to trauma',
                      'diagnosticCode' => '5010', 'lastAction' => nil },
                    { 'active' => false, 'date' => '2015-07-24',
                      'description' =>
                        'New and material evidence for service connection, degenerative spinal arthritis',
                      'diagnosticCode' => '5242',
                      'lastAction' => 'allowed' }],
                  'location' => 'aoj',
                  'programArea' => 'compensation',
                  'status' => { 'details' => {}, 'type' => 'remand_ssoc' },
                  'type' => 'post_remand',
                  'updated' => '2018-01-19T10:20:42-05:00' },
       'id' => '3294289',
       'type' => 'legacyAppeal' }]
  end

  def appeal_by_id(id, overrides: {}, without: [])
    appeal = appeals.find { |a| a['id'] == id }
    appeal['attributes'].merge!(overrides.stringify_keys) if overrides.any?
    without.each do |property|
      if property.is_a?(Hash)
        appeal[property[:at]].delete(property[:key])
      else
        appeal.delete(property)
      end
    end
    serializable_resource = OpenStruct.new(appeal['attributes'])
    serializable_resource[:id] = appeal['id']
    serializable_resource[:type] = appeal['type']
    subject.parse(serializable_resource)
  end

  context 'when status type has sc_received has a typo' do
    it 'converts typo to correct type' do
      appeal = appeal_by_id('3294289', overrides: {
                              status: { 'details' => {}, 'type' => 'sc_recieved' }
                            })
      expect(appeal.status.type).to eq('sc_received')
    end
  end

  context 'when docket is an empty hash' do
    it 'allows for empty hash docket value' do
      appeal = appeal_by_id('3294289', overrides: {
                              docket: {}
                            })

      expect(appeal.docket.to_json).to eq('{}')
    end
  end

  context 'when docket does not exist' do
    it 'creates empty hash value for docket' do
      appeal = appeal_by_id('3294289', without: [key: 'docket', at: 'attributes'])

      expect(appeal.docket.to_json).to eq('{}')
    end
  end

  context 'when alerts is an empty array' do
    it 'allows for empty array alerts value' do
      appeal = appeal_by_id('3294289', overrides: {
                              alerts: []
                            })

      expect(appeal.alerts).to eq([])
    end
  end

  context 'when alerts does not exist' do
    it 'sets alert to an empty array' do
      appeal = appeal_by_id('3294289', without: [key: 'alerts', at: 'attributes'])

      expect(appeal.alerts).to eq([])
    end
  end

  context 'when issue descriptions are blank or nil' do
    context "when appeal type is 'appeal' or 'legacyAppeal'" do
      it 'replaces blank or nil with an appeal type message' do
        appeal = appeal_by_id('3294289', overrides: {
                                issues: [
                                  { 'active' => true, 'date' => '2016-05-03',
                                    'description' => nil,
                                    'diagnosticCode' => '8100', 'lastAction' => 'remand' },
                                  { 'active' => true, 'date' => '2016-05-03',
                                    'description' => '',
                                    'diagnosticCode' => '5260', 'lastAction' => 'remand' }
                                ]
                              })

        expect(appeal.issues[0].description).to eq("We're unable to show this issue on appeal")
        expect(appeal.issues[1].description).to eq("We're unable to show this issue on appeal")
      end
    end

    context "when appeal type is 'higherLevelReview' or 'supplementalClaim'" do
      it 'replaces blank or nil with an appeal type message' do
        # Create a higherLevelReview appeal by modifying the top-level type
        appeal_data = appeals.find { |a| a['id'] == '3294289' }.dup
        appeal_data['type'] = 'higherLevelReview'
        appeal_data['attributes']['issues'] = [
          { 'active' => true, 'date' => '2016-05-03',
            'description' => nil,
            'diagnosticCode' => '8100', 'lastAction' => 'remand' }
        ]

        serializable_resource = OpenStruct.new(appeal_data['attributes'])
        serializable_resource[:id] = appeal_data['id']
        serializable_resource[:type] = appeal_data['type']
        appeal = subject.parse(serializable_resource)

        expect(appeal.issues[0].description).to eq("We're unable to show this issue on your Higher-Level Review")
      end
    end
  end
end
