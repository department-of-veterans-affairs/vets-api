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
    let(:new_form_class) { described_class.new(form_data) }

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
              'reports' => {
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

      let(:event_with_other_reports) do
        { 'events' => [{ 'otherReports' => 'incident report' }] }
      end

      context 'when police location details are present' do
        it 'formats the police report location correctly' do
          new_form_class.instance_variable_set(:@form_data, event_with_police_report)
          new_form_class.send(:process_reports)

          expect(new_form_class.instance_variable_get(:@form_data)['reportsDetails']['police']).to eq(
            'Local Police Department, Springfield, IL, USA'
          )
        end
      end

      context 'when otherReports are provided' do
        it 'collects and formats otherReports correctly' do
          new_form_class.instance_variable_set(:@form_data, event_with_other_reports)
          new_form_class.send(:process_reports)

          expect(new_form_class.instance_variable_get(:@form_data)['reportsDetails']['other']).to eq('incident report')
        end
      end
    end
  end

  describe '#set_report_types' do
    let(:event_with_other_reports) { { 'otherReports' => 'incident report' } }

    context 'when some reports are true' do
      it 'sets the correct values in @form_data' do
        form_data = {}
        new_form_class.instance_variable_set(:@form_data, form_data)

        reports = { 'restricted' => true, 'unrestricted' => false, 'neither' => false, 'police' => true }
        new_form_class.send(:set_report_types, event_with_other_reports, true, reports)

        expected_data = {
          'reportFiled' => 0,
          'restrictedReport' => 0,
          'unrestrictedReport' => nil,
          'neitherReport' => nil,
          'policeReport' => 3,
          'otherReport' => 4
        }

        expect(new_form_class.instance_variable_get(:@form_data)).to eq(expected_data)
      end
    end

    context 'when only otherReports is present' do
      it 'sets only otherReport' do
        form_data = {}
        new_form_class.instance_variable_set(:@form_data, form_data)

        reports = { 'restricted' => false, 'unrestricted' => false, 'neither' => false, 'police' => false }
        new_form_class.send(:set_report_types, event_with_other_reports, false, reports)

        expect(new_form_class.instance_variable_get(:@form_data)['otherReport']).to eq(4)
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
          'treatmentYear' => '2024',
          'noDates' => false
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
          'treatmentYear' => '2024',
          'noDates' => false
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
          'facilityInfo' => 'Veterans Medical Center',
          'noDates' => true
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
            'treatmentYear' => '2024',
            'noDates' => false
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
