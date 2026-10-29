module Types
  class UserAttributesInput < BaseInputObject
    description "Profile fields to change. Omitted fields stay as they are."

    argument :first_name, String, required: false, description: "Given name"
    argument :last_name, String, required: false, description: "Family name"
    argument :phone, String, required: false,
                             description: "Phone number with its country code (e.g. +1 201 555 0123)"
    argument :image, UploadType, required: false, description: "New profile image, or null to remove it"
  end
end
