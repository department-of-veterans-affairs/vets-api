# frozen_string_literal: true

require 'rails_helper'
require 'pdf_fill/forms/va210781v2'

def basic_class
  PdfFill::Forms::Va210781v2.new({})
end

describe PdfFill::Forms::Va210781v2 do
  let(:form_data) do
    {}
  end

  let(:new_form_class) do
    described_class.new(form_data)
  end

  def class_form_data
    new_form_class.instance_variable_get(:@form_data)
  end

  test_method(
    basic_class,
    'split_phone',
    [
      [[{}, nil], nil],
      [[{ phone: '1112223333' }, :phone], { 'first' => '111', 'second' => '222', 'third' => '3333' }],
      [[{ phone: '111-222-3333' }, :phone], { 'first' => '111', 'second' => '222', 'third' => '3333' }]
    ]
  )

  describe '#merge_fields' do
    it 'merges the right fields', run_at: '2024-03-21 00:00:00 EDT' do
      expect(described_class.new(get_fixture('pdf_fill/21-0781V2/kitchen_sink')).merge_fields.to_json).to eq(
        get_fixture('pdf_fill/21-0781V2/merge_fields').to_json
      )
    end
  end

  describe '#expand_signature' do
    let(:form_data) do
      { 'signatureDate' => '2017-02-14',
        'veteranFullName' => { 'first' => 'Foo',
                               'last' => 'Bar' } }
    end

    it 'expands the Signature and Signature Date correctly' do
      new_form_class.expand_signature(form_data['veteranFullName'], form_data['signatureDate'])

      expect(
        JSON.parse(new_form_class.instance_variable_get(:@form_data).to_json)
      ).to eq(
        { 'signature' => 'Foo Bar',
          'veteranFullName' => {
            'first' => 'Foo',
            'last' => 'Bar'
          },
          'signatureDate' => '2017-02-14' }
      )
    end
  end

  describe '#process_treatment_dates' do
    subject do
      new_form_class.instance_variable_set(:@form_data, { 'treatmentProvidersDetails' => details })
      new_form_class.send(:process_treatment_dates)
    end

    context 'when no treatment provider data is available' do
      let(:details) { nil }

      it 'returns successfully' do
        expect(subject).to be_nil
      end
    end

    context 'when treatment provider data is populated' do
      let(:details) do
        [
          { 'treatmentMonth' => '', 'treatmentYear' => '' },
          { 'treatmentMonth' => '02', 'treatmentYear' => '' },
          { 'treatmentMonth' => '', 'treatmentYear' => '2014' },
          { 'treatmentMonth' => '02', 'treatmentYear' => '2014' }
        ]
      end

      it 'sets the treatment dates accordingly and returns successfully' do
        subject
        result_details = new_form_class.instance_variable_get(:@form_data)['treatmentProvidersDetails']
        expect(result_details.pluck('treatmentDate')).to eq(['no response', '02-????', '2014', '02-2014'])
      end
    end
  end

  describe '#set_treatment_selection' do
    context 'when treatment providers are present' do
      it 'sets treatment to 0 and noTreatment to 0' do
        form_data = {}
        new_form_class.instance_variable_set(:@form_data, form_data)

        treatment_data = { 'medicalCenter' => true, 'nonVa' => true, 'vaPaid' => true }
        new_form_class.instance_variable_set(:@form_data, { 'treatmentProviders' => treatment_data })

        new_form_class.send(:set_treatment_selection)

        expected_data = {
          'treatmentProviders' => treatment_data,
          'treatment' => 0,
          'noTreatment' => 0
        }

        expect(new_form_class.instance_variable_get(:@form_data)).to eq(expected_data)
      end
    end

    context 'when no treatment providers but treatmentNoneCheckbox is true' do
      it 'sets treatment to 1 and noTreatment to 1' do
        form_data = {}
        new_form_class.instance_variable_set(:@form_data, form_data)

        new_form_class.instance_variable_set(:@form_data,
                                             { 'treatmentProviders' => {},
                                               'treatmentNoneCheckbox' => { 'none' => true } })

        new_form_class.send(:set_treatment_selection)

        expected_data = {
          'treatmentProviders' => {},
          'treatmentNoneCheckbox' => { 'none' => true },
          'treatment' => 1,
          'noTreatment' => 1
        }

        expect(new_form_class.instance_variable_get(:@form_data)).to eq(expected_data)
      end
    end

    context 'when no treatment providers' do
      it 'does not set treatment or noTreatment' do
        form_data = {}
        new_form_class.instance_variable_set(:@form_data, form_data)

        new_form_class.instance_variable_set(:@form_data, { 'treatmentProviders' => {} })

        new_form_class.send(:set_treatment_selection)

        expected_data = { 'treatmentProviders' => {} }

        expect(new_form_class.instance_variable_get(:@form_data)).to eq(expected_data)
      end
    end
  end

  describe '#process_reports' do
    context 'when no events data are provided' do
      it 'does nothing and leaves the data unchanged' do
        new_form_class.instance_variable_set(:@form_data, { 'events' => [] })
        new_form_class.send(:process_reports)

        expect(new_form_class.instance_variable_get(:@form_data)['events']).to eq([])
      end
    end

    context 'when report data are provided' do
      let(:event_with_police_report) do
        {
          'events' => [
            {
              'otherReports' => {
                'police' => true
              },
              'agency' => 'Local Police Department',
              'city' => 'Springfield',
              'state' => 'IL',
              'country' => 'USA'
            }
          ]
        }
      end

      let(:event_with_unlisted_reports) do
        { 'events' => [{ 'unlistedReport' => 'incident report' }] }
      end

      let(:event_with_no_report) do
        { 'events' => [{ 'otherReports' => { 'none' => true } }] }
      end

      let(:event_with_military_report) do
        { 'events' => [{ 'militaryReports' => { 'restricted' => true } }] }
      end

      context 'when police location details are present' do
        it 'formats the police report location correctly' do
          new_form_class.instance_variable_set(:@form_data, event_with_police_report)
          new_form_class.send(:process_reports)

          expect(new_form_class.instance_variable_get(:@form_data)['reportsDetails']['police']).to eq(
            'Local Police Department, Springfield, IL, USA'
          )
        end

        context 'when police location details overflow the text field' do
          let(:event_with_police_report) do
            {
              'events' => [
                {
                  'otherReports' => {
                    'police' => true
                  },
                  'agency' => 'Local Police Department',
                  'city' => 'Springfield',
                  'state' => 'IL',
                  'country' => 'USA'
                },
                {
                  'otherReports' => {
                    'police' => true
                  },
                  'agency' => 'Local Police Department',
                  'township' => 'Lower Alloways Creek Township',
                  'state' => 'NJ',
                  'country' => 'USA'
                }
              ]
            }
          end

          context 'when using the legacy overflow generator' do
            it 'does not populate the police report overflow data structure' do
              new_form_class.instance_variable_set(:@form_data, event_with_police_report)
              new_form_class.send(:process_reports)

              expect(new_form_class.instance_variable_get(:@form_data)).not_to have_key('policeReportOverflow')
            end
          end

          context 'when using the redesigned overflow generator' do
            it 'fills in the police report overflow data structure correctly' do
              new_form_class.instance_variable_set(:@form_data, event_with_police_report)
              new_form_class.send(:process_reports, extras_redesign: true)

              expect(new_form_class.instance_variable_get(:@form_data)['policeReportOverflow']).to eq(
                [
                  {
                    'agency' => 'Local Police Department',
                    'city' => 'Springfield',
                    'state' => 'IL',
                    'country' => 'USA'
                  },
                  {
                    'agency' => 'Local Police Department',
                    'township' => 'Lower Alloways Creek Township',
                    'state' => 'NJ',
                    'country' => 'USA'
                  }
                ]
              )
            end
          end
        end
      end

      context 'when an unlistedReport is provided' do
        it 'collects and formats unlistedReport correctly' do
          new_form_class.instance_variable_set(:@form_data, event_with_unlisted_reports)
          new_form_class.send(:process_reports)

          expect(new_form_class.instance_variable_get(:@form_data)['reportsDetails']['other']).to eq('incident report')
        end
      end

      context 'when at least one report is filed' do
        it 'sets reportFiled to 0' do
          new_form_class.instance_variable_set(:@form_data, event_with_military_report)
          new_form_class.send(:process_reports)

          expect(new_form_class.instance_variable_get(:@form_data)['reportFiled']).to eq(0)
          expect(new_form_class.instance_variable_get(:@form_data)['noReportFiled']).to be_nil
        end
      end

      context 'when no reports are filed' do
        it 'sets noReportFiled to 1' do
          new_form_class.instance_variable_set(:@form_data, event_with_no_report)
          new_form_class.send(:process_reports)

          expect(new_form_class.instance_variable_get(:@form_data)['noReportFiled']).to eq(1)
          expect(new_form_class.instance_variable_get(:@form_data)['reportFiled']).to be_nil
        end
      end

      context 'when both reportFiled and noReportFiled conditions are met' do
        it 'sets only reportFiled to 0' do
          new_form_class.instance_variable_set(:@form_data, {
                                                 'events' => [
                                                   {
                                                     'militaryReports' => { 'restricted' => true },
                                                     'otherReports' => { 'none' => true }
                                                   }
                                                 ]
                                               })
          new_form_class.send(:process_reports)

          expect(new_form_class.instance_variable_get(:@form_data)['reportFiled']).to eq(0)
          expect(new_form_class.instance_variable_get(:@form_data)['noReportFiled']).to be_nil
        end
      end
    end
  end

  describe '#set_report_types' do
    let(:event_with_unlisted_reports) { { 'unlistedReport' => 'incident report' } }

    context 'when some reports are true' do
      it 'sets the correct values in @form_data' do
        form_data = {}
        new_form_class.instance_variable_set(:@form_data, form_data)

        reports = { 'restricted' => true, 'unrestricted' => false, 'pre2005' => false, 'police' => true }
        new_form_class.send(:set_report_types, reports, event_with_unlisted_reports)

        expected_data = {
          'restrictedReport' => 0,
          'unrestrictedReport' => nil,
          'neitherReport' => nil,
          'policeReport' => 3,
          'otherReport' => 4
        }

        expect(new_form_class.instance_variable_get(:@form_data)).to eq(expected_data)
      end
    end

    context 'when only an unlistedReport is present' do
      it 'sets only otherReport' do
        form_data = {}
        new_form_class.instance_variable_set(:@form_data, form_data)

        reports = { 'restricted' => false, 'unrestricted' => false, 'pre2005' => false, 'police' => false }
        new_form_class.send(:set_report_types, reports, event_with_unlisted_reports)

        expect(new_form_class.instance_variable_get(:@form_data)['otherReport']).to eq(4)
      end
    end
  end

  describe '#process_behaviors_details' do
    let(:behaviors) do
      {
        'behaviors' => {
          'absences' => true,
          'appetite' => false
        },
        'behaviorsDetails' => {
          'absences' => 'absences lorem ipsum',
          'appetite' => 'appetite lorem ipsum'
        }
      }
    end

    let(:additional_behaviors) do
      {
        'behaviors' => {
          'unlisted' => true
        },
        'behaviorsDetails' => {
          'unlisted' => 'unlisted lorem ipsum'
        }
      }
    end

    context 'when extras_redesign is false (legacy mode)' do
      let(:extras_redesign) { false }

      context 'with standard behaviors data' do
        it 'transforms behaviors details into the expected format' do
          new_form_class.instance_variable_set(:@form_data, behaviors)
          new_form_class.send(:process_behaviors_details, extras_redesign)

          expected = [
            {
              'additionalInfo' => 'absences lorem ipsum',
              'description' => described_class::BEHAVIOR_DESCRIPTIONS['absences']
            },
            {
              'additionalInfo' => 'appetite lorem ipsum',
              'description' => described_class::BEHAVIOR_DESCRIPTIONS['appetite']
            }
          ]

          form_data = new_form_class.instance_variable_get(:@form_data)
          expect(form_data['behaviorsDetails']).to include(*expected)
          expect(form_data['behaviorsDetails'].select { |item| item['description'] }.size).to eq(2)
        end
      end

      context 'with additional behaviors data' do
        it 'transforms additional behaviors details into the expected format' do
          new_form_class.instance_variable_set(:@form_data, additional_behaviors)
          new_form_class.send(:process_behaviors_details, extras_redesign)

          form_data = new_form_class.instance_variable_get(:@form_data)
          expect(form_data['additionalBehaviorsDetails']).to eq(
            { 'additionalInfo' => 'unlisted lorem ipsum' }
          )
        end
      end

      [['nil', nil], ['blank', ''], ['missing', nil]].each do |test, value|
        context "with #{test} entry in behaviorsDetails" do
          before do
            data = behaviors.dup
            if test == 'missing'
              data['behaviorsDetails'].delete('appetite')
            else
              data['behaviorsDetails']['appetite'] = value
            end
            new_form_class.instance_variable_set(:@form_data, data)
          end

          it 'processes the behaviors properly' do
            new_form_class.send(:process_behaviors_details, extras_redesign)

            expected = {
              'additionalInfo' => 'absences lorem ipsum',
              'description' => described_class::BEHAVIOR_DESCRIPTIONS['absences']
            }

            form_data = new_form_class.instance_variable_get(:@form_data)
            expect(form_data['behaviorsDetails']).to include(expected)
            expect(form_data['behaviorsDetails'].select { |item| item['description'] }.size).to eq(1)
          end
        end
      end
    end

    context 'when extras_redesign is true' do
      let(:extras_redesign) { true }

      context 'with standard behaviors data' do
        before do
          new_form_class.instance_variable_set(:@form_data, behaviors)
          new_form_class.send(:process_behaviors_details, extras_redesign)
        end

        it 'transforms behaviors details into the expected format' do
          expected = [
            {
              'additionalInfo' => 'absences lorem ipsum',
              'checked' => true,
              'description' => described_class::BEHAVIOR_DESCRIPTIONS['absences']
            },
            {
              'additionalInfo' => 'appetite lorem ipsum',
              'checked' => false,
              'description' => described_class::BEHAVIOR_DESCRIPTIONS['appetite']
            }
          ]

          form_data = new_form_class.instance_variable_get(:@form_data)
          expect(form_data['behaviorsDetails']).to include(*expected)
          expect(form_data['behaviorsDetails'].select { |item| item['checked'] }.size).to eq(1)
        end
      end

      context 'with additional behaviors data' do
        it 'transforms additional behaviors details into the expected format' do
          new_form_class.instance_variable_set(:@form_data, additional_behaviors)
          new_form_class.send(:process_behaviors_details, extras_redesign)

          form_data = new_form_class.instance_variable_get(:@form_data)
          expect(form_data['additionalBehaviorsDetails']).to eq(
            [
              {
                'description' => 'Additional behavioral changes',
                'additionalInfo' => 'unlisted lorem ipsum',
                'checked' => true
              }
            ]
          )
        end
      end

      [['nil', nil], ['blank', ''], ['missing', nil]].each do |test, value|
        context "with #{test} entry in behaviorsDetails" do
          before do
            data = behaviors.dup
            if test == 'missing'
              data['behaviorsDetails'].delete('appetite')
            else
              data['behaviorsDetails']['appetite'] = value
            end
            new_form_class.instance_variable_set(:@form_data, data)
          end

          it 'processes the behaviors properly' do
            new_form_class.send(:process_behaviors_details, extras_redesign)
            expected = [
              {
                'additionalInfo' => 'absences lorem ipsum',
                'checked' => true,
                'description' => described_class::BEHAVIOR_DESCRIPTIONS['absences']
              },
              {
                'additionalInfo' => value,
                'checked' => false,
                'description' => described_class::BEHAVIOR_DESCRIPTIONS['appetite']
              }
            ]

            form_data = new_form_class.instance_variable_get(:@form_data)
            expect(form_data['behaviorsDetails']).to include(*expected)
            expect(form_data['behaviorsDetails'].select { |item| item['checked'] }.size).to eq(1)
          end
        end
      end
    end

    [true, false].each do |extras_redesign|
      context "when extras_redesign is #{extras_redesign}" do
        context 'when no behaviors or behavior_details are provided' do
          it 'returns nil and leaves the data unchanged' do
            new_form_class.instance_variable_set(:@form_data, { 'behaviors' => nil,
                                                                'behaviorsDetails' => nil,
                                                                'additionalBehaviorsDetails' => nil })
            new_form_class.send(:process_behaviors_details, extras_redesign)

            expect(new_form_class.instance_variable_get(:@form_data)).to eq(
              { 'behaviors' => nil, 'behaviorsDetails' => nil, 'additionalBehaviorsDetails' => nil }
            )
          end
        end

        context 'when behaviorsDetails is present but behaviors is missing' do
          it 'still processes the behaviorsDetails and additionalBehaviorsDetails' do
            new_form_class.instance_variable_set(:@form_data, { 'behaviors' => nil,
                                                                'behaviorsDetails' => {
                                                                  'absences' => 'absences lorem ipsum',
                                                                  'unlisted' => 'unlisted lorem ipsum'
                                                                } })
            new_form_class.send(:process_behaviors_details, extras_redesign)

            if extras_redesign
              expected_behaviors = { 'additionalInfo' => 'absences lorem ipsum',
                                     'checked' => false,
                                     'description' => described_class::BEHAVIOR_DESCRIPTIONS['absences'] }
              expected_additional_behaviors = [{ 'description' => 'Additional behavioral changes',
                                                 'additionalInfo' => 'unlisted lorem ipsum',
                                                 'checked' => false }]
            else
              expected_behaviors = { 'additionalInfo' => 'absences lorem ipsum',
                                     'description' => described_class::BEHAVIOR_DESCRIPTIONS['absences'] }

              expected_additional_behaviors = { 'additionalInfo' => 'unlisted lorem ipsum' }
            end

            form_data = new_form_class.instance_variable_get(:@form_data)
            expect(form_data['behaviorsDetails']).to include(expected_behaviors)
            expect(form_data['additionalBehaviorsDetails']).to eq(expected_additional_behaviors)
          end
        end
      end
    end
  end

  describe '#format_event' do
    context 'when event data are provided' do
      let(:event_data) do
        { 'details' => 'Sample event detail.', 'location' => 'Room 101', 'timing' => '2024-12-02' }
      end
      let(:index) { 1 }

      it 'formats the event correctly' do
        result = new_form_class.send(:format_event, event_data, index)

        expect(result).to eq(
          [
            'Event Number: 1',
            "Event Description: \n\nSample event detail.",
            "Event Location: \n\nRoom 101",
            "Event Date: \n\n2024-12-02"
          ]
        )
      end
    end

    context 'when event data are incomplete' do
      let(:incomplete_event_data) do
        { 'details' => 'Sample event detail.', 'location' => '', 'timing' => '' }
      end
      let(:index) { 2 }

      it 'formats the event correctly, ignoring empty fields' do
        result = new_form_class.send(:format_event, incomplete_event_data, index)

        expect(result).to eq(
          [
            'Event Number: 2',
            "Event Description: \n\nSample event detail.",
            "Event Location: \n\n",
            "Event Date: \n\n"
          ]
        )
      end
    end

    context 'when event data are blank' do
      let(:blank_event_data) { nil }
      let(:index) { 3 }

      it 'returns nil' do
        result = new_form_class.send(:format_event, blank_event_data, index)

        expect(result).to be_nil
      end
    end
  end

  describe '#format_provider' do
    context 'when treatment data are provided' do
      let(:treatment_data) do
        {
          'facilityInfo' => 'Veterans Medical Center',
          'treatmentMonth' => '01',
          'treatmentYear' => '2024'
        }
      end
      let(:index) { 1 }

      it 'formats the treatment information correctly' do
        result = new_form_class.send(:format_provider, treatment_data, index)

        expect(result).to eq(
          [
            'Treatment Information Number: 1',
            "Treatment Facility Name and Location: \n\nVeterans Medical Center",
            'Treatment Date: 01-2024'
          ]
        )
      end
    end

    context 'when some treatment data are missing' do
      let(:incomplete_treatment_data) do
        {
          'facilityInfo' => 'Veterans Medical Center',
          'treatmentYear' => '2024'
        }
      end
      let(:index) { 2 }

      it 'formats the treatment information correctly, using default values for missing fields' do
        result = new_form_class.send(:format_provider, incomplete_treatment_data, index)

        expect(result).to eq(
          [
            'Treatment Information Number: 2',
            "Treatment Facility Name and Location: \n\nVeterans Medical Center",
            'Treatment Date: XX-2024'
          ]
        )
      end
    end

    context 'when no treatment data are provided' do
      let(:blank_treatment_data) { nil }
      let(:index) { 3 }

      it 'returns nil' do
        result = new_form_class.send(:format_provider, blank_treatment_data, index)

        expect(result).to be_nil
      end
    end

    context 'when treatment has no date' do
      let(:no_date_treatment_data) do
        {
          'facilityInfo' => 'Veterans Medical Center'
        }
      end
      let(:index) { 4 }

      it 'formats the treatment information with "Don\'t have date" for missing dates' do
        result = new_form_class.send(:format_provider, no_date_treatment_data, index)

        expect(result).to eq(
          [
            'Treatment Information Number: 4',
            "Treatment Facility Name and Location: \n\nVeterans Medical Center",
            "Treatment Date: Don't have date"
          ]
        )
      end
    end
  end

  describe '#expand_collection' do
    context 'when eventsDetails is populated' do
      let(:event_details) do
        [
          { 'details' => 'Event 1 details', 'location' => 'Location 1', 'timing' => '2024-12-02' }
        ]
      end
      let(:formatted_event) do
        [
          'Event Number: 1',
          "Event Description: \n\nEvent 1 details",
          "Event Location: \n\nLocation 1",
          "Event Date: \n\n2024-12-02"
        ]
      end

      before do
        new_form_class.instance_variable_set(:@form_data, { 'eventsDetails' => event_details })
        new_form_class.send(:expand_collection, 'eventsDetails', :format_event, 'eventOverflow')
      end

      it 'formats the event correctly and assigns to eventOverflow' do
        event_overflow = new_form_class.instance_variable_get(:@form_data)['eventsDetails'][0]['eventOverflow']
        formatted_value = formatted_event.join("\n\n")

        expect(event_overflow).to be_a(PdfFill::FormValue)
        expect(event_overflow.extras_value).to eq(formatted_value)
      end
    end

    context 'when eventsDetails is empty' do
      it 'does nothing and leaves the data unchanged' do
        new_form_class.instance_variable_set(:@form_data, { 'eventsDetails' => [] })
        new_form_class.send(:expand_collection, 'eventsDetails', :format_event, 'eventOverflow')

        expect(new_form_class.instance_variable_get(:@form_data)['eventsDetails']).to eq([])
      end
    end

    context 'when treatmentProvidersDetails is populated' do
      let(:provider_details) do
        [
          {
            'facilityInfo' => 'Army Medical Center',
            'treatmentMonth' => '02',
            'treatmentYear' => '2024'
          }
        ]
      end
      let(:formatted_treatment) do
        [
          'Treatment Information Number: 1',
          "Treatment Facility Name and Location: \n\nArmy Medical Center",
          'Treatment Date: 02-2024'
        ]
      end

      before do
        new_form_class.instance_variable_set(:@form_data, { 'treatmentProvidersDetails' => provider_details })
        new_form_class.send(:expand_collection, 'treatmentProvidersDetails', :format_provider, 'providerOverflow')
      end

      it 'formats the treatment information and assigns it to providerOverflow' do
        form_data = new_form_class.instance_variable_get(:@form_data)
        provider_overflow = form_data['treatmentProvidersDetails'][0]['providerOverflow']
        formatted_value = formatted_treatment.join("\n\n")

        expect(provider_overflow).to be_a(PdfFill::FormValue)
        expect(provider_overflow.extras_value).to eq(formatted_value)
      end
    end

    context 'when treatmentProvidersDetails is empty' do
      it 'does nothing and leaves the data unchanged' do
        new_form_class.instance_variable_set(:@form_data, { 'treatmentProvidersDetails' => [] })
        new_form_class.send(:expand_collection, 'treatmentProvidersDetails', :format_provider, 'providerOverflow')

        expect(new_form_class.instance_variable_get(:@form_data)['treatmentProvidersDetails']).to eq([])
      end
    end
  end
end
