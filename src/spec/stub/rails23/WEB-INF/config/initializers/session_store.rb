# Be sure to restart your server when you modify this file.

# Your secret key for verifying cookie session data integrity.
# If you change this key, all old sessions will become invalid!
# Make sure the secret is at least 30 characters and all random, 
# no regular words or you'll be exposed to dictionary attacks.
ActionController::Base.session = {
  :key         => '_rails23_session',
  :secret      => 'f33cbc3660754c4f3175ee448a7a85a6de740e98acba5f4b2ac29268d6c3698225ef72b84b5d13e56dac0c0555a78767874f4495171cb3725d22e7d2afdba0fc'
}

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# ActionController::Base.session_store = :active_record_store
