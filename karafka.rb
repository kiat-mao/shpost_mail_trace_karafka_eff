# frozen_string_literal: true

#<% if rails? -%>
ENV['RAILS_ENV'] ||= 'production'
ENV['KARAFKA_ENV'] = ENV['RAILS_ENV']
require ::File.expand_path('../config/environment', __FILE__)
Rails.application.eager_load!

# This lines will make Karafka print to stdout like puma or unicorn
if Rails.env.development?
  Rails.logger.extend(
    ActiveSupport::Logger.broadcast(
      ActiveSupport::Logger.new($stdout)
    )
  )
end

# Auto reload
if Karafka::App.env.development?
  Karafka.monitor.subscribe(
    Karafka::CodeReloader.new(
      *Rails.application.reloaders
    )
  )
end
#<% else -%>
# This file is auto-generated during the install process.
# If by any chance you've wanted a setup for Rails app, either run the `karafka:install`
# command again or refer to the install templates available in the source codes

# ENV['RACK_ENV'] ||= 'development'
# ENV['KARAFKA_ENV'] ||= ENV['RACK_ENV']
# Bundler.require(:default, ENV['KARAFKA_ENV'])

# Zeitwerk custom loader for loading the app components before the whole
# Karafka framework configuration
# APP_LOADER = Zeitwerk::Loader.new
# APP_LOADER.enable_reloading

# %w[
#   lib
#   app/consumers
#   app/responders
#   app/workers
# ].each(&APP_LOADER.method(:push_dir))

# APP_LOADER.setup
# APP_LOADER.eager_load
#<% end -%>

class KarafkaApp < Karafka::App
  setup do |config|
    config.kafka.seed_brokers = %w[kafka://10.126.6.148:9092]
    config.client_id = 'Karafka'
# <% if rails? -%>
    config.logger = Rails.logger
# <% end -%>
    config.kafka.max_bytes_per_partition = 1024*1024
    config.kafka.session_timeout = 120
    config.kafka.min_bytes = 1024*1024*20
    config.kafka.max_wait_time = 30
    config.shutdown_timeout = 120

    # config.kafka.heartbeat_interval = 100
  end

  # Comment out this part if you are not using instrumentation and/or you are not
  # interested in logging events for certain environments. Since instrumentation
  # notifications add extra boilerplate, if you want to achieve max performance,
  # listen to only what you really need for given environment.
  Karafka.monitor.subscribe(WaterDrop::Instrumentation::StdoutListener.new)
  Karafka.monitor.subscribe(Karafka::Instrumentation::StdoutListener.new)
  Karafka.monitor.subscribe(Karafka::Instrumentation::ProctitleListener.new)

  # Uncomment that in order to achieve code reload in development mode
  # Be aware, that this might have some side-effects. Please refer to the wiki
  # for more details on benefits and downsides of the code reload in the
  # development mode
  #
  # Karafka.monitor.subscribe(
  #   Karafka::CodeReloader.new(
  #     <%= rails? ? '*Rails.application.reloaders' : 'APP_LOADER' %>
  #   )
  # )

  consumer_groups.draw do
    consumer_group :express_refresh_trace_group do
      batch_fetching true
      
      topic :mailtraceproduction do
        consumer ExpressConsumer
        batch_consuming true 
      end
    end


    # topic :example do
    #   consumer ExampleConsumer
    # end

    # consumer_group :bigger_group do
    #   topic :test do
    #     consumer TestConsumer
    #   end
    #
    #   topic :test2 do
    #     consumer Test2Consumer
    #   end
    # end
  end
end

Karafka.monitor.subscribe('app.initialized') do
  # Put here all the things you want to do after the Karafka framework
  # initialization
end

KarafkaApp.boot!