# THIS FREESWITCH LIBRARY HASN'T BEEN INTEGRATED INTO THE REFACTORED 0.8.0 YET.
# WHAT EXISTS HERE IS OLD, MUST BE CHANGED, AND DOES NOT EVEN GET LOADED AT THE MOMENT.
#require "adhearsion/voip/freeswitch/oes_server"
#require "adhearsion/voip/freeswitch/event_handler"
#require "adhearsion/voip/freeswitch/inbound_connection_manager"
#require "adhearsion/voip/dsl/dialplan/control_passing_exception"
#
#oes_enabled = Adhearsion::Configuration.core.voip.freeswitch.oes && Adhearsion::Configuration.core.voip.freeswitch.oes.port
#
#
#if oes_enabled
#
#  port = Adhearsion::Configuration.core.voip.freeswitch.oes.port
#  host = Adhearsion::Configuration.core.voip.freeswitch.oes.host
#
#  server = Adhearsion::VoIP::FreeSwitch::OesServer.new port, host
#
#  Events.register_callback(:after_initialized) { server.start }
#  Events.register_callback(:shutdown) { server.stop }
#  IMPORTANT_THREADS << server
#
#end



require 'adhearsion/voip/freeswitch'
module Adhearsion
  class Initializer

    class FreeSWITCHInitializer

      cattr_accessor :config, :agi_server, :ami_client
      class << self

        def start
          self.config     = AHN_CONFIG.freeswitch
          self.oes_server = initialize_oes
          #self.ies = VoIP::FreeSWITCH.eventsocket = initialize_ies if config.ies_enabled?
          join_server_thread_after_initialized

          # Make sure we stop everything when we shutdown
          Events.register_callback(:shutdown) do
            ahn_log.info "Shutting down FreeSWITCH connection with #{Adhearsion.active_calls.size} active calls"
            self.stop
          end
        end

        def stop
          oes_server.graceful_shutdown
          #ies_client.disconnect! if ies_client
        end

        private

        def initialize_oes
          VoIP::FreeSWITCH::EventSocket::OESServer.new :host => config.listening_host,
                                                       :port => config.listening_port
        end

        def initialize_ies
          options = ies_options
          start_ies_after_initialized
          returning VoIP::Asterisk::Manager::ManagerInterface.new(options) do
            class << VoIP::Asterisk
              if respond_to?(:manager_interface)
                ahn_log.warn "Asterisk.manager_interface already initialized?"
              else
                def manager_interface
                  # ahn_log.ami.warn "Warning! This Asterisk.manager_interface() notation is for Adhearsion version 0.8.0 only. Subsequent versions of Adhearsion will use a feature called SuperManager. Migrating to use SuperManager will be very simple. See http://docs.adhearsion.com/AMI for more information."
                  Adhearsion::Initializer::AsteriskInitializer.ami_client
                end
              end
            end
          end
        end

        def ami_options
          %w(host port username password events).inject({}) do |options, property|
            options[property.to_sym] = config.ami.send property
            options
          end
        end

        def join_server_thread_after_initialized
          Events.register_callback(:after_initialized) do
            begin
              oes_server.start
            rescue => e
              ahn_log.fatal "Failed to start OES server! #{e.inspect}"
              abort
            end
          end
          IMPORTANT_THREADS << oes_server
        end

        def start_ami_after_initialized
          Events.register_callback(:after_initialized) do
            begin
              self.ami_client.connect!
            rescue Errno::ECONNREFUSED
              ahn_log.ami.error "Connection refused when connecting to AMI! Please check your configuration."
            rescue => e
              ahn_log.ami.error "Error connecting to AMI! #{e.inspect}"
            end
          end
        end

      end
    end

  end
end

