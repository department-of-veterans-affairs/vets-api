# frozen_string_literal: true

module Facilities
  class VHAFacility < BaseFacility
    class << self
      attr_writer :validate_on_load

      def pull_source_data
        gis_type = 'FacilitySitePoint_VHA'
        sort_field = 'Sta_No'
        metadata = Facilities::GisMetadataClient.new.get_metadata(gis_type)
        max_record_count = metadata['maxRecordCount']
        Facilities::GisClient.new.get_all_facilities(gis_type, sort_field, max_record_count).map(&method(:new))
      end

      def service_list
        %w[PrimaryCare MentalHealthCare DentalServices UrgentCare EmergencyCare Audiology Cardiology Dermatology
           Gastroenterology Gynecology Ophthalmology Optometry Orthopedics Urology WomensHealth]
      end

      def mh_clinic_phone(attrs)
        val = attrs['MHClinicPhone']
        val = attrs['MHPhone'] if val.blank?
        return '' if val.blank?
        result = val.to_s
        result << ' x ' + attrs['Extension'].to_s unless
          (attrs['Extension']).blank? || (attrs['Extension']).zero?
        result
      end

      def zip_plus_four(attrs)
        zip = attrs['zip']
        zip4_is_empty = attrs['Zip4'].to_s.strip.empty? || attrs['Zip4'].to_s.strip == '0000'
        zip << "-#{attrs['Zip4']}" unless zip4_is_empty
        zip
      end

      def satisfaction_data(attrs)
        result = {}
        datum = FacilitySatisfaction.find(attrs['Sta_No'].upcase)
        if datum.present?
          datum.metrics.each { |k, v| result[k.to_s] = v.present? ? v.round(2).to_f : nil }
          result['effective_date'] = to_date(datum.source_updated)
        end
        result
      end

      def wait_time_data(attrs)
        result = {}
        datum = FacilityWaitTime.find(attrs['Sta_No'].upcase)
        if datum.present?
          datum.metrics.each { |k, v| result[k.to_s] = v }
          result['effective_date'] = to_date(datum.source_updated)
        end
        result
      end

      def identifier
        'Sta_No'
      end

      def attribute_map
        {
          'unique_id' => 'Sta_No',
          'name' => 'NAME',
          'classification' => 'CocClassificationID',
          'phone' => { 'main' => 'Sta_Phone', 'fax' => 'Sta_Fax',
                       'after_hours' => 'afterhoursphone',
                       'patient_advocate' => 'patientadvocatephone',
                       'enrollment_coordinator' => 'enrollmentcoordinatorphone',
                       'pharmacy' => 'pharmacyphone' },
          'physical' => { 'address_1' => 'Address2', 'address_2' => 'Address1',
                          'address_3' => 'Address3', 'city' => 'MUNICIPALITY', 'state' => 'STATE',
                          'zip' => method(:zip_plus_four) },
          'hours' => BaseFacility::HOURS_STANDARD_MAP,
          'access' => { 'health' => method(:wait_time_data) },
          'feedback' => { 'health' => method(:satisfaction_data) },
          'services' => services_map,
          'mapped_fields' => mapped_fields_list
        }
      end

      def services_map
        {
          'Audiology' => [],
          'ComplementaryAlternativeMed' => [],
          'DentalServices' => [],
          'DiagnosticServices' => %w[ImagingAndRadiology LabServices],
          'EmergencyDept' => [],
          'EyeCare' => [],
          'MentalHealthCare' => %w[OutpatientMHCare OutpatientSpecMHCare VocationalAssistance],
          'OutpatientMedicalSpecialty' => outpatient_medical_specialty_list,
          'OutpatientSurgicalSpecialty' => outpatient_surgical_specialty_list,
          'PrimaryCare' => [],
          'Rehabilitation' => [],
          'UrgentCare' => [],
          'WellnessAndPreventativeCare' => [],
          'DirectPatientSchedulingFlag' => []
        }
      end

      def outpatient_medical_specialty_list
        %w[
          AllergyAndImmunology CardiologyCareServices DermatologyCareServices
          Diabetes Dialysis Endocrinology Gastroenterology Hematology InfectiousDisease InternalMedicine
          Nephrology Neurology Oncology PulmonaryRespiratoryDisease Rheumatology SleepMedicine
        ]
      end

      def outpatient_surgical_specialty_list
        %w[CardiacSurgery ColoRectalSurgery ENT GeneralSurgery Gynecology Neurosurgery Orthopedics
           PainManagement PlasticSurgery Podiatry ThoracicSurgery Urology VascularSurgery]
      end

      def mapped_fields_list
        %w[Sta_No NAME CocClassificationID LASTUPDATE Address1 Address2 Address3 MUNICIPALITY STATE
           zip Zip4 Sta_Phone Sta_Fax afterhoursphone
           patientadvocatephone enrollmentcoordinatorphone pharmacyphone Monday
           Tuesday Wednesday Thursday Friday Saturday Sunday]
      end
    end
  end
end
