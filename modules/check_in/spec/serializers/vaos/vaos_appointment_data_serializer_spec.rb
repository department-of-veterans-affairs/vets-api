# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CheckIn::VAOS::VAOSAppointmentDataSerializer do
  subject { described_class }

  let(:vaos_appointment_data) do
    {
      data: [
        {
          id: '180765',
          identifier: [
            {
              system: 'Appointment/',
              value: '413938333130383735'
            },
            {
              system: 'http://www.va.gov/Terminology/VistADefinedTerms/409_84',
              value: '983:10875'
            }
          ],
          kind: 'clinic',
          status: 'booked',
          serviceType: 'amputation',
          serviceTypes: [
            {
              coding: [
                {
                  system: 'http://veteran.apps.va.gov/terminologies/fhir/CodeSystem/vats-service-type',
                  code: 'amputation'
                }
              ]
            }
          ],
          serviceCategory: [
            {
              coding: [
                {
                  system: 'http://www.va.gov/Terminology/VistADefinedTerms/409_1',
                  code: 'REGULAR',
                  display: 'REGULAR'
                }
              ],
              text: 'REGULAR'
            }
          ],
          patientIcn: '1013125218V696863',
          locationId: '983GC',
          clinic: '1081',
          start: '2023-11-06T16:00:00Z',
          end: '2023-11-06T16:30:00Z',
          minutesDuration: 30,
          slot: {
            id: '3230323331313036313630303A323032333131303631363330',
            start: '2023-11-06T16:00:00Z',
            end: '2023-11-06T16:30:00Z'
          },
          created: '2023-08-02T00:00:00Z',
          cancellable: true,
          extension: {
            ccLocation: {
              address: {}
            },
            vistaStatus: [
              'NO ACTION TAKEN'
            ],
            preCheckinAllowed: true,
            eCheckinAllowed: true
          }
        },
        {
          id: '180766',
          identifier: [
            {
              system: 'Appointment/',
              value: '413938333130383736'
            },
            {
              system: 'http://www.va.gov/Terminology/VistADefinedTerms/409_84',
              value: '983:10876'
            }
          ],
          kind: 'clinic',
          status: 'booked',
          serviceType: 'amputation',
          serviceTypes: [
            {
              coding: [
                {
                  system: 'http://veteran.apps.va.gov/terminologies/fhir/CodeSystem/vats-service-type',
                  code: 'amputation'
                }
              ]
            }
          ],
          serviceCategory: [
            {
              coding: [
                {
                  system: 'http://www.va.gov/Terminology/VistADefinedTerms/409_1',
                  code: 'REGULAR',
                  display: 'REGULAR'
                }
              ],
              text: 'REGULAR'
            }
          ],
          patientIcn: '1013125218V696863',
          locationId: '983GC',
          clinic: '1081',
          start: '2023-11-13T16:00:00Z',
          end: '2023-11-13T16:30:00Z',
          minutesDuration: 30,
          slot: {
            id: '3230323331313133313630303A323032333131313331363330',
            start: '2023-11-13T16:00:00Z',
            end: '2023-11-13T16:30:00Z'
          },
          created: '2023-08-02T00:00:00Z',
          cancellable: true,
          extension: {
            ccLocation: {
              address: {}
            },
            vistaStatus: [
              'FUTURE'
            ],
            preCheckinAllowed: true,
            eCheckinAllowed: true
          }
        },
        {
          id: '180767',
          identifier: [
            {
              system: 'Appointment/',
              value: '413938333130383737'
            },
            {
              system: 'http://www.va.gov/Terminology/VistADefinedTerms/409_84',
              value: '983:10877'
            }
          ],
          kind: 'clinic',
          status: 'booked',
          serviceType: 'amputation',
          serviceTypes: [
            {
              coding: [
                {
                  system: 'http://veteran.apps.va.gov/terminologies/fhir/CodeSystem/vats-service-type',
                  code: 'amputation'
                }
              ]
            }
          ],
          serviceCategory: [
            {
              coding: [
                {
                  system: 'http://www.va.gov/Terminology/VistADefinedTerms/409_1',
                  code: 'REGULAR',
                  display: 'REGULAR'
                }
              ],
              text: 'REGULAR'
            }
          ],
          patientIcn: '1013125218V696863',
          locationId: '983GC',
          clinic: '1081',
          start: '2023-11-20T16:00:00Z',
          end: '2023-11-20T16:30:00Z',
          minutesDuration: 30,
          slot: {
            id: '3230323331313230313630303A323032333131323031363330',
            start: '2023-11-20T16:00:00Z',
            end: '2023-11-20T16:30:00Z'
          },
          created: '2023-08-02T00:00:00Z',
          cancellable: true,
          extension: {
            ccLocation: {
              address: {}
            },
            vistaStatus: [
              'FUTURE'
            ],
            preCheckinAllowed: true,
            eCheckinAllowed: true
          }
        },
        {
          id: '180768',
          identifier: [
            {
              system: 'Appointment/',
              value: '413938333130383738'
            },
            {
              system: 'http://www.va.gov/Terminology/VistADefinedTerms/409_84',
              value: '983:10878'
            }
          ],
          kind: 'clinic',
          status: 'booked',
          serviceType: 'amputation',
          serviceTypes: [
            {
              coding: [
                {
                  system: 'http://veteran.apps.va.gov/terminologies/fhir/CodeSystem/vats-service-type',
                  code: 'amputation'
                }
              ]
            }
          ],
          serviceCategory: [
            {
              coding: [
                {
                  system: 'http://www.va.gov/Terminology/VistADefinedTerms/409_1',
                  code: 'REGULAR',
                  display: 'REGULAR'
                }
              ],
              text: 'REGULAR'
            }
          ],
          patientIcn: '1013125218V696863',
          locationId: '983GC',
          clinic: '1081',
          start: '2023-11-27T16:00:00Z',
          end: '2023-11-27T16:30:00Z',
          minutesDuration: 30,
          slot: {
            id: '3230323331313237313630303A323032333131323731363330',
            start: '2023-11-27T16:00:00Z',
            end: '2023-11-27T16:30:00Z'
          },
          created: '2023-08-02T00:00:00Z',
          cancellable: true,
          extension: {
            ccLocation: {
              address: {}
            },
            vistaStatus: [
              'FUTURE'
            ],
            preCheckinAllowed: true,
            eCheckinAllowed: true
          }
        }
      ]
    }
  end

  context 'For valid vaos appointment data' do
    let(:appointment1) do
      {
        id: '180765',
        identifier: [
          {
            system: 'Appointment/',
            value: '413938333130383735'
          },
          {
            system: 'http://www.va.gov/Terminology/VistADefinedTerms/409_84',
            value: '983:10875'
          }
        ],
        kind: 'clinic',
        status: 'booked',
        serviceType: 'amputation',
        locationId: '983GC',
        clinic: '1081',
        start: '2023-11-06T16:00:00Z',
        end: '2023-11-06T16:30:00Z',
        extension: {
          ccLocation: {
            address: {}
          },
          vistaStatus: [
            'NO ACTION TAKEN'
          ],
          preCheckinAllowed: true,
          eCheckinAllowed: true
        }
      }
    end
    let(:appointment2) do
      {
        id: '180766',
        identifier: [
          {
            system: 'Appointment/',
            value: '413938333130383736'
          },
          {
            system: 'http://www.va.gov/Terminology/VistADefinedTerms/409_84',
            value: '983:10876'
          }
        ],
        kind: 'clinic',
        status: 'booked',
        serviceType: 'amputation',
        locationId: '983GC',
        clinic: '1081',
        start: '2023-11-13T16:00:00Z',
        end: '2023-11-13T16:30:00Z',
        extension: {
          ccLocation: {
            address: {}
          },
          vistaStatus: [
            'FUTURE'
          ],
          preCheckinAllowed: true,
          eCheckinAllowed: true
        }
      }
    end
    let(:appointment3) do
      {
        id: '180767',
        identifier: [
          {
            system: 'Appointment/',
            value: '413938333130383737'
          },
          {
            system: 'http://www.va.gov/Terminology/VistADefinedTerms/409_84',
            value: '983:10877'
          }
        ],
        kind: 'clinic',
        status: 'booked',
        serviceType: 'amputation',
        locationId: '983GC',
        clinic: '1081',
        start: '2023-11-20T16:00:00Z',
        end: '2023-11-20T16:30:00Z',
        extension: {
          ccLocation: {
            address: {}
          },
          vistaStatus: [
            'FUTURE'
          ],
          preCheckinAllowed: true,
          eCheckinAllowed: true
        }
      }
    end
    let(:appointment4) do
      {
        id: '180768',
        identifier: [
          {
            system: 'Appointment/',
            value: '413938333130383738'
          },
          {
            system: 'http://www.va.gov/Terminology/VistADefinedTerms/409_84',
            value: '983:10878'
          }
        ],
        kind: 'clinic',
        status: 'booked',
        serviceType: 'amputation',
        locationId: '983GC',
        clinic: '1081',
        start: '2023-11-27T16:00:00Z',
        end: '2023-11-27T16:30:00Z',
        extension: {
          ccLocation: {
            address: {}
          },
          vistaStatus: [
            'FUTURE'
          ],
          preCheckinAllowed: true,
          eCheckinAllowed: true
        }
      }
    end

    let(:serialized_hash_response) do
      {
        data:
          {
            id: nil,
            type: :vaos_appointment_data,
            attributes:
              {
                appointments:
                [
                  appointment1, appointment2, appointment3, appointment4
                ]
              }
          }
      }
    end

    it 'returns a serialized hash' do
      appt_struct = OpenStruct.new(vaos_appointment_data)
      appt_serializer = subject.new(appt_struct)
      expect(appt_serializer.serializable_hash).to eq(serialized_hash_response)
    end
  end

  context 'Missing serialization key' do
    let(:vaos_appointment_data_without_identifier) do
      {
        data: [
          {
            id: '180765',
            kind: 'clinic',
            status: 'booked',
            serviceType: 'amputation',
            serviceTypes: [
              {
                coding: [
                  {
                    system: 'http://veteran.apps.va.gov/terminologies/fhir/CodeSystem/vats-service-type',
                    code: 'amputation'
                  }
                ]
              }
            ],
            serviceCategory: [
              {
                coding: [
                  {
                    system: 'http://www.va.gov/Terminology/VistADefinedTerms/409_1',
                    code: 'REGULAR',
                    display: 'REGULAR'
                  }
                ],
                text: 'REGULAR'
              }
            ],
            patientIcn: '1013125218V696863',
            locationId: '983GC',
            clinic: '1081',
            start: '2023-11-06T16:00:00Z',
            end: '2023-11-06T16:30:00Z',
            minutesDuration: 30,
            slot: {
              id: '3230323331313036313630303A323032333131303631363330',
              start: '2023-11-06T16:00:00Z',
              end: '2023-11-06T16:30:00Z'
            },
            created: '2023-08-02T00:00:00Z',
            cancellable: true,
            extension: {
              ccLocation: {
                address: {}
              },
              vistaStatus: [
                'NO ACTION TAKEN'
              ],
              preCheckinAllowed: true,
              eCheckinAllowed: true
            }
          }
        ]
      }
    end

    let(:appointment_without_identifier) do
      {
        id: '180765',
        kind: 'clinic',
        status: 'booked',
        serviceType: 'amputation',
        locationId: '983GC',
        clinic: '1081',
        start: '2023-11-06T16:00:00Z',
        end: '2023-11-06T16:30:00Z',
        extension: {
          ccLocation: {
            address: {}
          },
          vistaStatus: [
            'NO ACTION TAKEN'
          ],
          preCheckinAllowed: true,
          eCheckinAllowed: true
        }
      }
    end
    let(:serialized_hash_response) do
      {
        data:
          {
            id: nil,
            type: :vaos_appointment_data,
            attributes:
              {
                appointments:
                  [
                    appointment_without_identifier
                  ]
              }
          }
      }
    end

    it 'identifier not present' do
      appt_struct = OpenStruct.new(vaos_appointment_data_without_identifier)
      appt_serializer = subject.new(appt_struct)
      expect(appt_serializer.serializable_hash).to eq(serialized_hash_response)
    end
  end
end
