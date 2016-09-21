require_dependency 'facilities/client'

class VAHealthFacility < ActiveModelSerializers::Model
  attr_accessor :id, :visn_id, :name, :classification, :lat, :long, 
                :address, :phone, :hours, :services

  def self.query(bbox:)
    results = client.query(bbox: bbox)
    results.each_with_object([]) do | record, facs |
      facs << VAHealthFacility.from_gis(record)
    end
  end

  def self.find_by_id(id:)
    results = client.get(identifier: id)
    VAHealthFacility.from_gis(results.first)
  end

  def self.from_gis(record)
    attrs = record['attributes']
    VAHealthFacility.new(
      id: attrs['StationID'],
      visn_id: attrs['VisnID'],
      name: attrs['StationName'],
      classification: attrs['CocClassification'],
      lat: attrs['Latitude'],
      long: attrs['Longitude'],
      address: VAHealthFacility.address_from_gis(attrs),
      phone: VAHealthFacility.phone_from_gis(attrs),
      hours: VAHealthFacility.hours_from_gis(attrs),
      services: VAHealthFacility.services_from_gis(attrs)
    )
  end

  def self.address_from_gis(attrs)
    {
      'building' => attrs['Building'],
      'street' => attrs['Street'],
      'suite' => attrs['Suite'],
      'city' => attrs['City'],
      'state' => attrs['State'],
      'zip' => attrs['Zip'],
      'zip4' => attrs['Zip4']
    }
  end

  def self.phone_from_gis(attrs)
    {
      'main' => attrs['MainPhone'],
      'fax' => attrs['MainFax'],
      'after_hours' => attrs['AfterHoursPhone'],
      'patient_advocate' => attrs['PatientAdvocatePhone'],
      'enrollment_coordinator' => attrs['EnrollmentCoordinatorPhone'],
      'pharmacy' =>  attrs['PharmacyPhone']
    }
  end

  WEEK_KEYS = 
    ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']

  def self.hours_from_gis(attrs)
    WEEK_KEYS.each_with_object({}) { | k, h | h[k] = attrs[k] } 
  end

  SERVICE_HIERARCHY = { 
    "Audiology" => [],
    "ComplementaryAlternativeMed" => [],
    "DentalServices" => [],
    "DiagnosticServices" => [
      "ImagingAndRadiology", "LabServices"],
    "EmergencyDept" => [],
    "EyeCare" => [],
    "MentalHealthCare" => [
      "OutpatientMHCare", "OutpatientSpecMHCare", "VocationalAssistance"],
    "OutpatientMedicalSpecialty" => [
      "AllergyAndImmunology", "CardiologyCareServices", "DermatologyCareServices",
      "Diabetes", "Dialysis", "Endocrinology", "Gastroenterology",
      "Hematology", "InfectiousDisease", "InternalMedicine",
      "Nephrology", "Neurology", "Oncology",
      "PulmonaryRespiratoryDisease", "Rheumatology", "SleepMedicine"],
    "OutpatientSurgicalSpecialty" => [
      "CardiacSurgery", "ColoRectalSurgery", "ENT", "GeneralSurgery",
      "Gynecology", "Neurosurgery", "Orthopedics", "PainManagement",
      "PlasticSurgery", "Podiatry", "ThoracicSurgery", "Urology",
      "VascularSurgery"],
    "PrimaryCare" => [],
    "Rehabilitation" => [],
    "UrgentCare" => [],
    "WellnessAndPreventativeCare" => []
  }

  def self.services_from_gis(attrs)
    SERVICE_HIERARCHY.each_with_object([]) do | (k,v), l |
      if attrs[k] == 'YES'
        sl = []
        v.each do | sk |
          sl << sk if attrs[sk] == 'YES' 
        end
        l << [k, sl]
      end
    end
  end


  def self.service_hash_from_gis(attrs)
    SERVICE_HIERARCHY.each_with_object({}) do | (k,v), h |
      if attrs[k] == 'YES'
        h[k] = []
        v.each do | sk |
          h[k] << sk if attrs[sk] == 'YES' 
        end
      end
    end
  end

  protected

  URL = "https://maps.va.gov/server/rest/services/PROJECTS/Facility_Locator/MapServer"
  LAYER = 0
  ID_FIELD = "StationID"

  def self.client
    puts URL
    puts LAYER
    client ||= Facilities::Client.new(url: URL, layer: LAYER, id_field: ID_FIELD)
  end

end
