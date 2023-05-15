# frozen_string_literal: true

%w[
  10-10EZ
  10-10CG
].each do |schema|
  VetsJsonSchema::SCHEMAS[schema] = IceNine.deep_freeze(VetsJsonSchema::SCHEMAS[schema])
end
