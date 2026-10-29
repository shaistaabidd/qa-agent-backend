# Creates the first super admin from the environment, never from hardcoded values:
#   SUPER_ADMIN_EMAIL=you@example.com SUPER_ADMIN_PASSWORD='S3cure!pass' bin/rails db:seed
email = ENV.fetch("SUPER_ADMIN_EMAIL", nil)
password = ENV.fetch("SUPER_ADMIN_PASSWORD", nil)

if email.present? && password.present?
  User.find_or_create_by!(email:) do |user|
    user.role = :super_admin
    user.password = password
    user.password_confirmation = password
  end
  puts "Super admin ready: #{email}"
else
  puts "Skipped super admin: set SUPER_ADMIN_EMAIL and SUPER_ADMIN_PASSWORD."
end
