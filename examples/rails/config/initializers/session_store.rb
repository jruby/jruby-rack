# Be sure to restart your server when you modify this file.

# Your secret key for verifying cookie session data integrity.
# If you change this key, all old sessions will become invalid!
# Make sure the secret is at least 30 characters and all random,
# no regular words or you'll be exposed to dictionary attacks.
ActionController::Base.session = {
#   :disabled    => true,
  :key         => '_rails_session',
  :secret      => 'd652b8fa9b4e4e3018165d86310675170607c3eab5cc2e029d67187cee015a777ebf09dd19adfd3929e4e48c27f83bbec0c7eee101dfe08e1418669009fe93e9'
}

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# ActionController::Base.session_store = :active_record_store

if defined?($servlet_context)
  require 'action_controller/session/java_servlet_store'
  ActionController::Base.session_store = :java_servlet_store
end
