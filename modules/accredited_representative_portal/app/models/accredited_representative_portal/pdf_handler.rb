# frozen_string_literal: true

# require 'pdf_forms'

module AccreditedRepresentativePortal
  class PdfHandler
    attr_reader :pdf, :pdf_path, :output_path

    def initialize(pdf_path, output_path)
      @pdf_path = pdf_path
      @output_path = output_path
      # @pdf = PdfForms.new(Settings.binaries.pdftk)
      @pdf = HexaPDF::Document.open(pdf_path)
    end

    # def fill_form(field_data)
    #   pdf.fill_form(pdf_path, output_path, field_data)
    # end

    def fill_form(field_data)
      acro_form = pdf.acro_form
      acro_form.fill(field_data)

      pdf.write(output_path)
    end

    # def extract_data(path)
    #   pdf.get_fields(path).map { |row| { name: row.name, value: row.value } }
    # end
    def extract_data
      acro_form = pdf.acro_form
      fields = []
      acro_form.each_field do |field|    
        fields.push({ name: field.field_name, value: field[:V] } )
      end
      fields
    end
    
  end
end

# example fields
# "F[0].Page_7[0].#subform[0].VeteranFirstName[0]"
# "F[0].Page_7[0].#subform[0].ZIPOrPostalCode_LastFourNumbers[0]"


# initially unclear fields
# "F[0].Page_7[0].#subform[0].NO[0]"  => "1" -> is your spouse a veteran
# "F[0].Page_7[0].#subform[0].YES[1]" -> do you live together
# "F[0].Page_7[0].#subform[0].CheckBox1[0]" -> do you agree to electronic correspondence






#  {:name=>"F[0].Page_7[0].#subform[0].Claimants_Middle_Initial1[0]"
#  {:name=>"F[0].Page_7[0].#subform[0].CurrentMailingAddress_NumberAndStreet[0]", :value=>nil},
#  {:name=>"F[0].Page_7[0].#subform[0].CurrentMailingAddress_ZIPOrPostalCode_LastFourNumbers[0]", :value=>nil},
#  {:name=>"F[0].Page_7[0].#subform[0].CurrentMailingAddress_ZIPOrPostalCode_FirstFiveNumbers[0]", :value=>nil},
#  {:name=>"F[0].Page_7[0].#subform[0].CurrentMailingAddress_Country[0]", :value=>nil},
#  {:name=>"F[0].Page_7[0].#subform[0].CurrentMailingAddress_StateOrProvince[0]", :value=>nil},
#  {:name=>"F[0].Page_7[0].#subform[0].CurrentMailingAddress_City[0]", :value=>nil},
#  {:name=>"F[0].Page_7[0].#subform[0].CurrentMailingAddress_ApartmentOrUnitNumber[0]", :value=>nil},
#  {:name=>"F[0].Page_7[0].#subform[0].TelephoneNumber_LastFourNumbers[0]", :value=>nil},
#  {:name=>"F[0].Page_7[0].#subform[0].TelephoneNumber_SecondThreeNumbers[0]", :value=>nil},
#  {:name=>"F[0].Page_7[0].#subform[0].TelephoneNumber_AreaCode_FirstThreeNumbers[0]", :value=>nil},

#  {:name=>"F[0].Page_7[0].#subform[0].PlaceOfMarriage_Country[0]", :value=>nil},
#  {:name=>"F[0].Page_7[0].#subform[0].PlaceOfMarriage_StateOrProvince[0]", :value=>nil},
#  {:name=>"F[0].Page_7[0].#subform[0].PlaceOfMarriage_City_Or_County[0]", :value=>nil},
#  {:name=>"F[0].Page_7[0].#subform[0].Spouses_VA_File_Number[0]", :value=>nil},
#  {:name=>"F[0].Page_7[0].#subform[0].International_Telephone_Number_If_Applicable[0]", :value=>nil},
#  {:name=>"F[0].Page_7[0].#subform[0].CIVIL_Justice_Of_The_Peace[0]", :value=>"Off"},
#  {:name=>"F[0].Page_7[0].#subform[0].OTHER_Explain[1]", :value=>nil},
#  {:name=>"F[0].Page_8[0].#subform[0].Last_Name[0]", :value=>nil},
#  {:name=>"F[0].Page_8[0].#subform[0].Middle_Initial[0]", :value=>nil},
#  {:name=>"F[0].Page_8[0].#subform[0].First_Name[0]", :value=>nil},
#  {:name=>"F[0].Page_8[0].#subform[0].Year[0]", :value=>nil},
#  {:name=>"F[0].Page_8[0].#subform[0].Day[0]", :value=>nil},
#  {:name=>"F[0].Page_8[0].#subform[0].Month[0]", :value=>nil},
#  {:name=>"F[0].Page_8[0].#subform[0].Country[0]", :value=>nil},
#  {:name=>"F[0].Page_8[0].#subform[0].StateOrProvince[0]", :value=>nil},
#  {:name=>"F[0].Page_8[0].#subform[0].City_Or_County[0]", :value=>nil}



# use this for field_data
#  {
#   "F[0].Page_7[0].#subform[0].VeteranFirstName[0]"=>"Jane",
#   "F[0].Page_7[0].#subform[0].VeteranMiddleInitial1[0]"=>"A",
#   "F[0].Page_7[0].#subform[0].VeteranLastName[0]"=>"Smith",
#   "F[0].Page_7[0].#subform[0].Veterans_SocialSecurityNumber_FirstThreeNumbers[0]"=>"111",
#   "F[0].Page_7[0].#subform[0].Veterans_SocialSecurityNumber_SecondTwoNumbers[0]"=>"22",
#   "F[0].Page_7[0].#subform[0].Veterans_SocialSecurityNumber_LastFourNumbers[0]"=>"3333",
#   "F[0].Page_7[0].#subform[0].VAFileNumber[0]"=>"123456789",
#   "F[0].Page_7[0].#subform[0].DOBmonth[0]"=>"05",
#   "F[0].Page_7[0].#subform[0].DOBday[0]"=>"20",
#   "F[0].Page_7[0].#subform[0].DOByear[0]"=>"1980",
#   "F[0].Page_7[0].#subform[0].ZIPOrPostalCode_LastFourNumbers[0]" => "4444",
#   "F[0].Page_7[0].#subform[0].ZIPOrPostalCode_FirstFiveNumbers[0]" => "55555",
#   "F[0].Page_7[0].#subform[0].Country[0]" => "US",
#   "F[0].Page_7[0].#subform[0].StateOrProvince[0]" => "NY",
#   "F[0].Page_7[0].#subform[0].City[0]" => "New York",
#   "F[0].Page_7[0].#subform[0].ApartmentOrUnitNumber[0]" => "1B",
#   "F[0].Page_7[0].#subform[0].CompleteMailingAddress_NumberAndStreet[0]" => "123 Main St",
#   "F[0].Page_7[0].#subform[0].SPOUSE_LastName[0]" => "Clandorf",
#   "F[0].Page_7[0].#subform[0].SPOUSE_MiddleInitial1[0]" => "T",
#   "F[0].Page_7[0].#subform[0].SPOUSE_CURRENT_LEGAL_NAME_FirstName[0]" => "Livia",
#   "F[0].Page_7[0].#subform[0].Claimants_Last_Name[0]" => "Clandorf",
#   "F[0].Page_7[0].#subform[0].Claimants_First_Name[0]" => "Stella",
#   "F[0].Page_7[0].#subform[0].Claimants_Social_Security_Number_LastFourNumbers[0]" => "8888",
#   "F[0].Page_7[0].#subform[0].Claimants_Social_Security_Number_SecondTwoNumbers[0]" => "77",
#   "F[0].Page_7[0].#subform[0].Claimants_Social_Security-Number_FirstThreeNumbers[0]" => "666",
#   "F[0].Page_7[0].#subform[0].Veterans_Service_Number[0]" => "098765432",
#   "F[0].Page_7[0].#subform[0].DOByear[1]" => "1994",
#   "F[0].Page_7[0].#subform[0].DOBday[1]" => "17",
#   "F[0].Page_7[0].#subform[0].DOBmonth[1]" => "08",
#   "F[0].Page_7[0].#subform[0].SpouseSocialSecurityNumber_LastFourNumbers[0]" => "1111",
#   "F[0].Page_7[0].#subform[0].SpouseSocialSecurityNumber_SecondTwoNumbers[0]" => "00",
#   "F[0].Page_7[0].#subform[0].SpouseSocialSecurityNumber_FirstThreeNumbers[0]" => "999",
#   "F[0].Page_7[0].#subform[0].DOMARRIAGEyear[0]" => "2023",
#   "F[0].Page_7[0].#subform[0].DOMARRIAGEday[0]" => "27",
#   "F[0].Page_7[0].#subform[0].DOMARRIAGEmonth[0]" => "05",
#   "F[0].Page_7[0].#subform[0].OTHER_Explain[0]" => "Off",
#   "F[0].Page_7[0].#subform[0].Tribal[0]" => "Off",
#   "F[0].Page_7[0].#subform[0].Proxy[0]" => "Off",
#   "F[0].Page_7[0].#subform[0].CommonLaw[0]" => "1",
#   "F[0].Page_7[0].#subform[0].ReligiousCeremony[0]" => "Off",
#   "F[0].Page_7[0].#subform[0].NO[0]" => "1",
#   "F[0].Page_7[0].#subform[0].YES[0]" => "Off",
#   "F[0].Page_7[0].#subform[0].NO[1]" => "Off",
#   "F[0].Page_7[0].#subform[0].YES[1]" => "1",
#   "F[0].Page_7[0].#subform[0].Email_Address[0]" => "test@test.com",
#   "F[0].Page_7[0].#subform[0].Reason_For_Separation[0]" => "lack of stella pets",
#   "F[0].Page_7[0].#subform[0].CheckBox1[0]" => "Off",
# }
