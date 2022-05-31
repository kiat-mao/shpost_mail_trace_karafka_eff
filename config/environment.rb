# Load the Rails application.
require_relative 'application'

# Initialize the Rails application.
Rails.application.initialize!

# Rails.root.join(Karafka.boot_file)
require Rails.root.join(Karafka.boot_file)