FactoryBot.define do
  factory :role_credential do
    project
    role_name { 'admin' }
    encrypted_credential_ref { 's3cr3t-password' }
  end
end
