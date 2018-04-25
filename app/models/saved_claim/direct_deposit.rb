class SavedClaim::DirectDeposit < CentralMailClaim
  # id of the form, must be the same as the id in the directory name of the associated json schema
  # for example the path to this models's schema is vets-json-schema/src/schemas/21P-530/schema.js
  FORM = '24-0296'  

  def regional_office
    "I'm a regional Office"
  end

end