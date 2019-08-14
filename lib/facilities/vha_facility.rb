# frozen_string_literal: true

module Facilities
  class VHAFacility < BaseFacility

  	class << self
	    attr_writer :validate_on_load

	    def pull_source_data
	      metadata = Facilities::MetadataClient.new.get_metadata(arcgis_type)
	      max_record_count = metadata['maxRecordCount']
	      Facilities::Client.new.get_all_facilities(arcgis_type, sort_field, max_record_count).map(&method(:new))
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
		      zip = attrs['Zip']
		      zip << "-#{attrs['Zip4']}" unless attrs['Zip4'].to_s.strip.empty?
		      zip
		    end

		    def satisfaction_data(attrs)
		      result = {}
		      datum = FacilitySatisfaction.find(attrs['StationNumber'].upcase)
		      if datum.present?
		        datum.metrics.each { |k, v| result[k.to_s] = v.present? ? v.round(2).to_f : nil }
		        result['effective_date'] = to_date(datum.source_updated)
		      end
		      result
		    end

		    def wait_time_data(attrs)
		      result = {}
		      datum = FacilityWaitTime.find(attrs['StationNumber'].upcase)
		      if datum.present?
		        datum.metrics.each { |k, v| result[k.to_s] = v }
		        result['effective_date'] = to_date(datum.source_updated)
		      end
		      result
		    end

	    def arcgis_type
	    	'VHA_Facilities'
	    end

	    def sort_field
	    	'StationNumber'
	    end
	  end

	  VHA_MAP = {
	    'unique_id' => 'StationNumber',
	    'name' => 'StationName',
	    'classification' => 'CocClassification',
	    'website' => 'Website_URL',
	    'phone' => { 'main' => 'MainPhone', 'fax' => 'MainFax',
	                 'after_hours' => 'AfterHoursPhone',
	                 'patient_advocate' => 'PatientAdvocatePhone',
	                 'enrollment_coordinator' => 'EnrollmentCoordinatorPhone',
	                 'pharmacy' => 'PharmacyPhone', 'mental_health_clinic' => method(:mh_clinic_phone) },
	    'physical' => { 'address_1' => 'Street', 'address_2' => 'Building',
	                    'address_3' => 'Suite', 'city' => 'City', 'state' => 'State',
	                    'zip' => method(:zip_plus_four) },
	    'hours' => HOURS_STANDARD_MAP,
	    'access' => { 'health' => method(:wait_time_data) },
	    'feedback' => { 'health' => method(:satisfaction_data) },
	    'services' => {
	      'Audiology' => [],
	      'ComplementaryAlternativeMed' => [],
	      'DentalServices' => [],
	      'DiagnosticServices' => %w[
	        ImagingAndRadiology LabServices
	      ],
	      'EmergencyDept' => [],
	      'EyeCare' => [],
	      'MentalHealthCare' => %w[
	        OutpatientMHCare OutpatientSpecMHCare VocationalAssistance
	      ],
	      'OutpatientMedicalSpecialty' => %w[
	        AllergyAndImmunology CardiologyCareServices DermatologyCareServices
	        Diabetes Dialysis Endocrinology Gastroenterology
	        Hematology InfectiousDisease InternalMedicine
	        Nephrology Neurology Oncology
	        PulmonaryRespiratoryDisease Rheumatology SleepMedicine
	      ],
	      'OutpatientSurgicalSpecialty' => %w[
	        CardiacSurgery ColoRectalSurgery ENT GeneralSurgery
	        Gynecology Neurosurgery Orthopedics PainManagement
	        PlasticSurgery Podiatry ThoracicSurgery Urology
	        VascularSurgery
	      ],
	      'PrimaryCare' => [],
	      'Rehabilitation' => [],
	      'UrgentCare' => [],
	      'WellnessAndPreventativeCare' => [],
	      'DirectPatientSchedulingFlag' => []
	    },
	    'mapped_fields' => %w[StationNumber StationName CocClassification FacilityDataDate Website_URL Latitude Longitude
	                          Street Building Suite City State Zip Zip4 MainPhone MainFax AfterHoursPhone
	                          PatientAdvocatePhone EnrollmentCoordinatorPhone PharmacyPhone MHPhone Extension Monday
	                          Tuesday Wednesday Thursday Friday Saturday Sunday SHEP_Primary_Care_Routine
	                          SHEP_Primary_Care_Urgent Hematology SHEP_Specialty_Care_Routine SHEP_Specialty_Care_Urgent
	                          SHEP_ScoreDateRange PrimaryCare MentalHealthCare DentalServices Audiology ENT
	                          ComplementaryAlternativeMed DiagnosticServices ImagingAndRadiology LabServices
	                          EmergencyDept EyeCare OutpatientMHCare OutpatientSpecMHCare VocationalAssistance
	                          OutpatientMedicalSpecialty AllergyAndImmunology CardiologyCareServices UrgentCare
	                          DermatologyCareServices Diabetes Dialysis Endocrinology Gastroenterology InfectiousDisease
	                          InternalMedicine Nephrology Neurology Oncology PulmonaryRespiratoryDisease Rheumatology
	                          SleepMedicine OutpatientSurgicalSpecialty CardiacSurgery ColoRectalSurgery
	                          GeneralSurgery Gynecology Neurosurgery Orthopedics PainManagement PlasticSurgery Podiatry
	                          ThoracicSurgery Urology VascularSurgery Rehabilitation WellnessAndPreventativeCare]
	  }.freeze

  end
end
