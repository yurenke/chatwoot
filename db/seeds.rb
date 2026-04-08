# ----------------------------------------
# Load installation configs
# ----------------------------------------
GlobalConfig.clear_cache
ConfigLoader.new.process

# ----------------------------------------
# Ensure default settings
# ----------------------------------------
installation_config = InstallationConfig.find_by(name: 'CREATE_NEW_ACCOUNT_FROM_DASHBOARD')

if installation_config
  installation_config.update!(value: true)
end

GlobalConfig.clear_cache

# ----------------------------------------
# Create default account
# ----------------------------------------
account = Account.find_or_create_by!(name: 'PlayAce')

# ----------------------------------------
# Create admin user
# ----------------------------------------
admin_email = ENV.fetch('ADMIN_EMAIL', 'admin@example.com')
admin_password = ENV.fetch('ADMIN_PASSWORD', 'password123!')

admin = User.find_or_create_by!(email: admin_email) do |u|
  u.name = 'PlayAce CS Admin'
  u.password = admin_password
  u.password_confirmation = admin_password
  u.type = 'SuperAdmin'
end

# 確保已驗證（避免登入問題）
admin.skip_confirmation! if admin.respond_to?(:skip_confirmation!)
admin.save! if admin.changed?

# ----------------------------------------
# Assign admin to account
# ----------------------------------------
AccountUser.find_or_create_by!(
  account: account,
  user: admin
) do |au|
  au.role = :administrator
end

# ----------------------------------------
# Done
# ----------------------------------------
puts "Seed completed:"
puts "Account: #{account.name}"
puts "Admin: #{admin.email}"