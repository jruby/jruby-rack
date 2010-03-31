# Be sure to restart your server when you modify this file.

# Your secret key for verifying cookie session data integrity.
# If you change this key, all old sessions will become invalid!
# Make sure the secret is at least 30 characters and all random, 
# no regular words or you'll be exposed to dictionary attacks.
ActionController::Base.session = {
  :key         => '_rails_session',
  :secret      => '603e4819eb9da3e711dd95c56aced75a9689abf963af8e47c190b4215aa22fd1a7389c000e708a05ac6b6e8d8f7ed9168010d4e14862d9d10a602c7fccf107a1'
}

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# ActionController::Base.session_store = :active_record_store

ActionController::Base.session_store = :java_servlet_store if defined?($servlet_context)

